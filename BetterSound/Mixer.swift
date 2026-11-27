import AppKit
import AudioToolbox
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
    /// Bluetooth battery in %, by device UID. Read when the panel opens.
    @Published private(set) var battery: [String: Int] = [:]

    @Published private var volumes: [String: Float]   // slider position 0...1, persisted
    @Published private var muted: Set<String>
    @Published private var routes: [String: String]   // bundle ID -> device UID, persisted

    private var taps: [String: AppTap] = [:]
    var debugState: String { "volumes=\(volumes) taps=\(taps.mapValues { "\($0.deviceUID) gain=\($0.gain) peak=\($0.peakLevel)" })" }
    // Core Audio tells us when something changes: nothing runs while idle.
    private var systemListeners: [AudioListener] = []
    private var processListeners: [AudioObjectID: AudioListener] = [:]
    private var volumeListeners: [AudioListener] = []
    /// Bluetooth devices appear before their output stream: listen for the stream to show up.
    private var streamListeners: [AudioObjectID: AudioListener] = [:]
    private var listenedDevice = AudioObjectID(kAudioObjectUnknown)
    private var refreshPending = false
    private var owners: [pid_t: Owner?] = [:]
    private let defaults = UserDefaults.standard

    init() {
        // NSNumber -> Float bridging fails for doubles that are not exact floats: go through floatValue.
        volumes = (defaults.dictionary(forKey: "volumes") as? [String: NSNumber] ?? [:]).mapValues(\.floatValue)
        muted = Set(defaults.stringArray(forKey: "muted") ?? [])
        routes = defaults.dictionary(forKey: "routes") as? [String: String] ?? [:]
        systemListeners = [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice]
            .map { AudioListener(.system, $0, onChange: changed) }
            + [AudioListener(.system, kAudioHardwarePropertyProcessObjectList, onChange: processesChanged)]
        refresh()
    }

    /// Short-lived audio clients appear and vanish several times a second without playing:
    /// only listen to them, and refresh when one is playing or one of our rows lost a process.
    private nonisolated func processesChanged() {
        MainActor.assumeIsolated {
            // One call for the list; ask Core Audio about new processes only.
            let ids = Set(AudioObjectID.system.readArray(kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self))
            let rowLost = apps.contains { !$0.processes.isSubset(of: ids) }
            let newPlaying = ids.contains {
                processListeners[$0] == nil && $0.read(kAudioProcessPropertyIsRunningOutput, default: UInt32(0)) != 0
            }
            watch(ids)
            if rowLost || newPlaying { changed() }
        }
    }

    /// Several properties change at once (a device switch, an app starting): refresh once.
    private nonisolated func changed() {
        MainActor.assumeIsolated {
            guard !refreshPending else { return }
            refreshPending = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                MainActor.assumeIsolated {
                    self?.refreshPending = false
                    self?.refresh()
                }
            }
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
        taps = [:]   // gone before the switch, or macOS switches back to the device it plays on
        Audio.defaultOutput = device.id
        refresh()
    }

    /// Bluetooth battery from system_profiler (no Bluetooth permission needed, ~0.3 s): the lower
    /// of both earbuds, else the device's single level. Bluetooth audio UIDs are the address with dashes.
    func refreshBattery() {
        Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
            p.arguments = ["SPBluetoothDataType", "-json"]
            let pipe = Pipe()
            p.standardOutput = pipe
            guard (try? p.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            let connected = ((root?["SPBluetoothDataType"] as? [[String: Any]])?.first?["device_connected"] as? [[String: Any]]) ?? []
            var levels: [String: Int] = [:]
            for entry in connected {
                for case let info as [String: Any] in entry.values {
                    guard let address = info["device_address"] as? String else { continue }
                    let values = ["device_batteryLevelLeft", "device_batteryLevelRight", "device_batteryLevelMain"]
                        .compactMap { (info[$0] as? String).flatMap { Int($0.filter(\.isNumber)) } }
                    if let low = values.min() { levels[address.replacingOccurrences(of: ":", with: "-") + ":output"] = low }
                }
            }
            await MainActor.run { [levels] in self.battery = levels }
        }
    }

    func requestPermission() {
        AudioPermission.request { [weak self] in
            self?.permission = AudioPermission.status
            self?.apply()
        }
    }

    // MARK: State sync

    func refresh() {
        // Assign only what changed: every @Published write redraws the panel and the icon.
        let newDevices = Audio.outputDevices()
        if newDevices != devices { devices = newDevices }
        let all = Set(AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, of: AudioObjectID.self))
        streamListeners = streamListeners.filter { all.contains($0.key) }
        for id in all where streamListeners[id] == nil {
            streamListeners[id] = AudioListener(id, kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput, onChange: changed)
        }
        let newDefault = Audio.defaultOutput
        if newDefault != defaultDeviceID { defaultDeviceID = newDefault }
        let m = Audio.masterVolume
        if hasMaster != (m != nil) { hasMaster = m != nil }
        if let m, case let v = Audio.masterMuted ? 0 : m, v != master { master = v }
        let p = AudioPermission.status
        if p != permission { permission = p }
        let processes = Audio.processes()
        watch(Set(processes.map(\.objectID)))
        let newApps = currentApps(processes)
        if newApps.map(\.id) != apps.map(\.id) || newApps.map(\.processes) != apps.map(\.processes) { apps = newApps }
        apply()
    }

    /// Listen to each process starting or stopping output, and to the default output's volume.
    private func watch(_ ids: Set<AudioObjectID>) {
        processListeners = processListeners.filter { ids.contains($0.key) }
        for id in ids where processListeners[id] == nil {
            processListeners[id] = AudioListener(id, kAudioProcessPropertyIsRunningOutput, onChange: changed)
        }
        guard listenedDevice != defaultDeviceID else { return }
        listenedDevice = defaultDeviceID
        let out = kAudioObjectPropertyScopeOutput
        volumeListeners = [kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioDevicePropertyMute]
            .map { AudioListener(defaultDeviceID, $0, out, onChange: changed) }
    }

    /// Apps with a playing process, plus apps we're already handling (so a paused app keeps its row).
    private func currentApps(_ processes: [AudioProcess]) -> [AppRow] {
        let me = ProcessInfo.processInfo.processIdentifier
        var byApp: [String: AppRow] = [:]
        var playing = Set<String>()
        // Short-lived audio clients come and go several times a second: resolve each pid once.
        owners = owners.filter { pid in processes.contains { $0.pid == pid.key } }
        for p in processes where p.pid > 0 && p.pid != me {
            if owners[p.pid] == nil { owners[p.pid] = .some(Audio.owner(p.pid)) }
            guard let owner = owners[p.pid] ?? nil, owner.pid != me else { continue }
            let id = owner.id
            if byApp[id] == nil {
                byApp[id] = apps.first { $0.id == id }.map { AppRow(id: id, name: $0.name, icon: $0.icon, processes: []) }
                    ?? AppRow(id: id, name: owner.name.isEmpty ? id : owner.name, icon: owner.icon, processes: [])
            }
            byApp[id]?.processes.insert(p.objectID)
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
