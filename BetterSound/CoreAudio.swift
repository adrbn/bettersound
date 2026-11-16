import AppKit
import AudioToolbox
import CoreAudio
import Foundation

// Thin helpers over the AudioObject property API.

extension AudioObjectID {
    static let system = AudioObjectID(kAudioObjectSystemObject)

    func address(_ selector: AudioObjectPropertySelector,
                 _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    func read<T>(_ selector: AudioObjectPropertySelector,
                 _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                 default value: T) -> T {
        var addr = address(selector, scope)
        var result = value
        var size = UInt32(MemoryLayout<T>.size)
        let err = AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &result)
        return err == noErr ? result : value
    }

    func readArray<T>(_ selector: AudioObjectPropertySelector,
                      _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                      of: T.Type) -> [T] {
        var addr = address(selector, scope)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(self, &addr, 0, nil, &size) == noErr, size > 0 else { return [] }
        let count = Int(size) / MemoryLayout<T>.stride
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<T>.alignment)
        defer { buffer.deallocate() }
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, buffer) == noErr else { return [] }
        return Array(UnsafeBufferPointer(start: buffer.bindMemory(to: T.self, capacity: count), count: count))
    }

    func readString(_ selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(self, &addr, 0, nil, &size, &value) == noErr,
              let str = value?.takeRetainedValue() else { return nil }
        return str as String
    }

    @discardableResult
    func write<T>(_ selector: AudioObjectPropertySelector, _ value: T,
                  scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> OSStatus {
        var addr = address(selector, scope)
        var v = value
        return AudioObjectSetPropertyData(self, &addr, 0, nil, UInt32(MemoryLayout<T>.size), &v)
    }
}

// MARK: - Output devices

struct OutputDevice: Identifiable, Hashable {
    let id: AudioObjectID
    let uid: String
    let name: String
    let transport: UInt32

    /// Speakers get a level icon in the menu bar; headphones and the like show the device.
    var isSpeaker: Bool { ["laptopcomputer", "hifispeaker", "display", "cable.connector"].contains(symbol) }

    var symbol: String {
        let lower = name.lowercased()
        if lower.contains("airpods max") { return "airpodsmax" }
        if lower.contains("airpods pro") { return "airpods.pro" }
        if lower.contains("airpods") { return "airpods" }
        if lower.contains("beats") { return "beats.headphones" }
        switch transport {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "headphones"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort: return "display"
        case kAudioDeviceTransportTypeAirPlay: return "airplayaudio"
        case kAudioDeviceTransportTypeUSB: return "cable.connector"
        case kAudioDeviceTransportTypeBuiltIn: return lower.contains("headphone") ? "headphones" : "laptopcomputer"
        default: return "hifispeaker"
        }
    }
}

enum Audio {
    static func outputDevices() -> [OutputDevice] {
        AudioObjectID.system.readArray(kAudioHardwarePropertyDevices, of: AudioObjectID.self).compactMap { id in
            let streams = id.readArray(kAudioDevicePropertyStreams, kAudioObjectPropertyScopeOutput, of: AudioStreamID.self)
            guard !streams.isEmpty,
                  let uid = id.readString(kAudioDevicePropertyDeviceUID),
                  let name = id.readString(kAudioObjectPropertyName) else { return nil }
            let transport: UInt32 = id.read(kAudioDevicePropertyTransportType, default: 0)
            // Hide aggregates/virtual devices macOS itself doesn't show in the Sound menu.
            if transport == kAudioDeviceTransportTypeAggregate || uid.hasPrefix("CADefaultDeviceAggregate") { return nil }
            return OutputDevice(id: id, uid: uid, name: name, transport: transport)
        }
    }

    static var defaultOutput: AudioObjectID {
        get { AudioObjectID.system.read(kAudioHardwarePropertyDefaultOutputDevice, default: AudioObjectID(kAudioObjectUnknown)) }
        set { AudioObjectID.system.write(kAudioHardwarePropertyDefaultOutputDevice, newValue) }
    }

    /// Master volume of the default output, nil when the device has no software volume (HDMI, etc.).
    static var masterVolume: Float? {
        get {
            let dev = defaultOutput
            var addr = dev.address(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput)
            guard AudioObjectHasProperty(dev, &addr) else { return nil }
            return dev.read(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, kAudioObjectPropertyScopeOutput, default: Float32(0))
        }
        set {
            guard let v = newValue else { return }
            let dev = defaultOutput
            dev.write(kAudioHardwareServiceDeviceProperty_VirtualMainVolume, Float32(v), scope: kAudioObjectPropertyScopeOutput)
            dev.write(kAudioDevicePropertyMute, UInt32(v == 0 ? 1 : 0), scope: kAudioObjectPropertyScopeOutput)
        }
    }

    static var masterMuted: Bool {
        defaultOutput.read(kAudioDevicePropertyMute, kAudioObjectPropertyScopeOutput, default: UInt32(0)) != 0
    }
}

// MARK: - Audio processes

struct AudioProcess {
    let objectID: AudioObjectID
    let pid: pid_t
    let isPlaying: Bool
}

@_silgen_name("responsibility_get_pid_responsible_for_pid")
private func responsibility_get_pid_responsible_for_pid(_ pid: pid_t) -> pid_t

extension Audio {
    static func processes() -> [AudioProcess] {
        AudioObjectID.system.readArray(kAudioHardwarePropertyProcessObjectList, of: AudioObjectID.self).map { obj in
            AudioProcess(objectID: obj,
                         pid: obj.read(kAudioProcessPropertyPID, default: pid_t(-1)),
                         isPlaying: obj.read(kAudioProcessPropertyIsRunningOutput, default: UInt32(0)) != 0)
        }
    }

    /// Helper processes (WebKit GPU, XPC services) play on behalf of an app; attribute them to it.
    static func responsiblePID(_ pid: pid_t) -> pid_t {
        let r = responsibility_get_pid_responsible_for_pid(pid)
        return r > 0 ? r : pid
    }

    /// The app a process belongs to: its responsible process, or the first ancestor that is an app
    /// (CLI tools and helpers launched by an app, e.g. a binary inside Claude.app).
    static func owningApp(_ pid: pid_t) -> NSRunningApplication? {
        var p = responsiblePID(pid)
        for _ in 0..<8 where p > 1 {
            if let app = NSRunningApplication(processIdentifier: p), app.bundleIdentifier != nil { return app }
            var info = kinfo_proc(), size = MemoryLayout<kinfo_proc>.size
            var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, p]
            guard sysctl(&mib, 4, &info, &size, nil, 0) == 0 else { return nil }
            p = info.kp_eproc.e_ppid
        }
        return nil
    }
}
