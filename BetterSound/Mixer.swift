import AppKit
import CoreAudio
import Foundation

struct AppRow: Identifiable {
    let id: String          // bundle ID (or "pid:N" for apps without one)
    let name: String
    let icon: NSImage
    var processes: Set<AudioObjectID>
}

@MainActor
final class Mixer: ObservableObject {
    @Published private(set) var apps: [AppRow] = []
    @Published private(set) var devices: [OutputDevice] = []
    @Published private(set) var defaultDeviceID = AudioObjectID(kAudioObjectUnknown)
    @Published var master: Float = 0
    @Published private(set) var hasMaster = true
    @Published private(set) var permission = AudioPermission.status

    @Published private var volumes: [String: Float]   // slider position 0...1, persisted
    @Published private var muted: Set<String>
    @Published private var routes: [String: String]   // bundle ID -> device UID, persisted

    private var taps: [String: AppTap] = [:]
    var debugState: String { "volumes=\(volumes) taps=\(taps.mapValues { "\($0.deviceUID) gain=\($0.gain) peak=\($0.peakLevel)" })" }
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    init() {
        volumes = defaults.dictionary(forKey: "volumes") as? [String: Float] ?? [:]
        muted = Set(defaults.stringArray(forKey: "muted") ?? [])
        routes = defaults.dictionary(forKey: "routes") as? [String: String] ?? [:]
        refresh()
        // ponytail: 1 s polling; switch to AudioObject property listeners if it ever shows in Activity Monitor.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    // MARK: Queries for the UI

    var menuBarSymbol: String {
        let device = devices.first { $0.id == defaultDeviceID }
        if let device, !device.isSpeaker { return device.symbol }
        switch master {
        case 0: return "speaker.slash.fill"
        case ..<0.34: return "speaker.wave.1.fill"
        case ..<0.67: return "speaker.wave.2.fill"
        default: return "speaker.wave.3.fill"
        }
    }

    func volume(_ id: String) -> Float { volumes[id] ?? 1 }
    func isMuted(_ id: String) -> Bool { muted.contains(id) }
    func route(_ id: String) -> String? { routes[id] }

    // MARK: Actions

    func setVolume(_ id: String, _ v: Float) {
        volumes[id] = v
        if v > 0 { muted.remove(id) }
        save(); apply()
    }

    func toggleMute(_ id: String) {
        if muted.contains(id) { muted.remove(id) } else { muted.insert(id) }
        save(); apply()
    }

    func setRoute(_ id: String, _ uid: String?) {
        routes[id] = uid
        save(); apply()
    }

    func setMaster(_ v: Float) {
        master = v
        Audio.masterVolume = v
    }

    func selectDefault(_ device: OutputDevice) {
        Audio.defaultOutput = device.id
        refresh()
    }

    func requestPermission() {
        AudioPermission.request { [weak self] in
            self?.permission = AudioPermission.status
            self?.apply()
        }
    }

    // MARK: State sync

    func refresh() {
        devices = Audio.outputDevices()
        defaultDeviceID = Audio.defaultOutput
        if let m = Audio.masterVolume {
            hasMaster = true
            master = Audio.masterMuted ? 0 : m
        } else {
            hasMaster = false
        }
        permission = AudioPermission.status
        apps = currentApps()
        apply()
    }

    /// Apps with a playing process, plus apps we're already handling (so a paused app keeps its row).
    private func currentApps() -> [AppRow] {
        let me = ProcessInfo.processInfo.processIdentifier
        var byApp: [String: AppRow] = [:]
        var playing = Set<String>()
        for p in Audio.processes() where p.pid > 0 && p.pid != me {
            let owner = Audio.responsiblePID(p.pid)
            guard owner != me, let app = NSRunningApplication(processIdentifier: owner) else { continue }
            let id = app.bundleIdentifier ?? "pid:\(owner)"
            byApp[id, default: AppRow(id: id,
                                      name: app.localizedName ?? id,
                                      icon: app.icon ?? NSImage(),
                                      processes: [])].processes.insert(p.objectID)
            if p.isPlaying { playing.insert(id) }
        }
        return byApp.values
            .filter { playing.contains($0.id) || taps[$0.id] != nil }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Create, update or drop taps so each app matches its settings. Apps at 100% on the
    /// system output get no tap at all: their audio is untouched.
    private func apply() {
        let uids = Set(devices.map(\.uid))
        let defaultUID = devices.first { $0.id == defaultDeviceID }?.uid
        var wanted: Set<String> = []

        for app in apps {
            let gain = muted.contains(app.id) ? 0 : pow(volume(app.id), 2)
            // A chosen device that's gone (headphones unplugged) falls back to the system output;
            // the choice is kept and applies again when the device comes back.
            let chosen = routes[app.id].flatMap { uids.contains($0) ? $0 : nil }
            guard permission == .granted, gain < 1 || chosen != nil,
                  let uid = chosen ?? defaultUID else { continue }
            wanted.insert(app.id)

            if let tap = taps[app.id], tap.processes == app.processes, tap.deviceUID == uid {
                tap.gain = gain
            } else {
                taps[app.id] = nil   // tear down the old one before the new tap mutes the app
                taps[app.id] = AppTap(processes: app.processes, deviceUID: uid, gain: gain)
            }
        }
        for id in taps.keys where !wanted.contains(id) { taps[id] = nil }
    }

    private func save() {
        defaults.set(volumes, forKey: "volumes")
        defaults.set(Array(muted), forKey: "muted")
        defaults.set(routes, forKey: "routes")
    }
}

/// System audio capture permission ("Screen & System Audio Recording"). No public API to
/// check it, so this uses the TCC SPI like other open-source tap apps do.
enum AudioPermission {
    case granted, denied, unknown

    private static let tcc = dlopen("/System/Library/PrivateFrameworks/TCC.framework/Versions/A/TCC", RTLD_NOW)
    private static let service = "kTCCServiceAudioCapture" as CFString

    static var status: AudioPermission {
        typealias Preflight = @convention(c) (CFString, CFDictionary?) -> Int
        guard let sym = dlsym(tcc, "TCCAccessPreflight") else { return .unknown }
        switch unsafeBitCast(sym, to: Preflight.self)(service, nil) {
        case 0: return .granted
        case 1: return .denied
        default: return .unknown
        }
    }

    static func request(_ done: @escaping @MainActor () -> Void) {
        typealias Request = @convention(c) (CFString, CFDictionary?, @escaping @convention(block) (Bool) -> Void) -> Void
        guard let sym = dlsym(tcc, "TCCAccessRequest") else { return }
        unsafeBitCast(sym, to: Request.self)(service, nil) { _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { done() } }
        }
    }
}
