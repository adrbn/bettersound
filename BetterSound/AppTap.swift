import AudioToolbox
import CoreAudio
import Foundation
import os

private let log = Logger(subsystem: "dev.adrbn.bettersound", category: "tap")

/// Mutes one app at the source (process tap, `.mutedWhenTapped`) and replays its audio,
/// scaled by `gain`, on a chosen output device through a private aggregate device.
final class AppTap {
    let processes: Set<AudioObjectID>
    let deviceUID: String

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var procID: AudioDeviceIOProcID?
    // Shared with the real-time thread. Aligned Float32 loads/stores don't tear on arm64.
    private let target = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    private let current = UnsafeMutablePointer<Float>.allocate(capacity: 1)
    /// Loudest input sample since the last check: tells a working tap from a silent one (no permission).
    private let peak = UnsafeMutablePointer<Float>.allocate(capacity: 1)

    var peakLevel: Float { peak.pointee }

    var gain: Float {
        get { target.pointee }
        set { target.pointee = newValue }
    }

    init?(processes: Set<AudioObjectID>, deviceUID: String, gain: Float) {
        self.processes = processes
        self.deviceUID = deviceUID
        target.pointee = gain
        current.pointee = gain
        peak.pointee = 0
        do {
            try start()
            log.info("tap on \(deviceUID, privacy: .public) gain \(gain)")
            let peak = self.peak
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                guard self != nil else { return }
                log.info("tap peak after 2 s: \(peak.pointee)")
            }
        } catch {
            log.error("tap failed: \(error.localizedDescription, privacy: .public)")
            stop()
            return nil
        }
    }

    deinit {
        stop()
        target.deallocate()
        current.deallocate()
        peak.deallocate()
    }

    private func start() throws {
        let desc = CATapDescription(stereoMixdownOfProcesses: Array(processes))
        desc.uuid = UUID()
        desc.muteBehavior = .mutedWhenTapped
        desc.isPrivate = true
        try check(AudioHardwareCreateProcessTap(desc, &tapID), "create tap")

        let config: [String: Any] = [
            kAudioAggregateDeviceNameKey: "BetterSound",
            kAudioAggregateDeviceUIDKey: "dev.adrbn.bettersound." + UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: deviceUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceSubDeviceListKey: [[kAudioSubDeviceUIDKey: deviceUID]],
            kAudioAggregateDeviceTapListKey: [[
                kAudioSubTapDriftCompensationKey: true,
                kAudioSubTapUIDKey: desc.uuid.uuidString,
            ]],
        ]
        try check(AudioHardwareCreateAggregateDevice(config as CFDictionary, &aggregateID), "create aggregate")

        let target = self.target, current = self.current, peak = self.peak
        try check(AudioDeviceCreateIOProcIDWithBlock(&procID, aggregateID, nil) { _, input, _, output, _ in
            AppTap.render(input: input, output: output, target: target.pointee, current: current, peak: peak)
        }, "create IOProc")
        try check(AudioDeviceStart(aggregateID, procID), "start device")
    }

    private func stop() {
        if aggregateID != kAudioObjectUnknown {
            if let procID {
                AudioDeviceStop(aggregateID, procID)
                AudioDeviceDestroyIOProcID(aggregateID, procID)
            }
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
        procID = nil
    }

    /// Real-time thread: copy the tap (last input buffer, interleaved stereo) into the first
    /// output buffer, ramping the gain across the buffer to avoid zipper noise.
    private static func render(input: UnsafePointer<AudioBufferList>,
                               output: UnsafeMutablePointer<AudioBufferList>,
                               target: Float,
                               current: UnsafeMutablePointer<Float>,
                               peak: UnsafeMutablePointer<Float>) {
        let outs = UnsafeMutableAudioBufferListPointer(output)
        for buf in outs { if let d = buf.mData { memset(d, 0, Int(buf.mDataByteSize)) } }

        let ins = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: input))
        guard let src = ins.last, let srcData = src.mData,
              let dst = outs.first, let dstData = dst.mData else { return }

        let inCh = Int(max(src.mNumberChannels, 1)), outCh = Int(max(dst.mNumberChannels, 1))
        let frames = min(Int(src.mDataByteSize) / (4 * inCh), Int(dst.mDataByteSize) / (4 * outCh))
        guard frames > 0 else { return }
        let s = srcData.assumingMemoryBound(to: Float.self)
        let d = dstData.assumingMemoryBound(to: Float.self)

        var g = current.pointee
        let step = (target - g) / Float(frames)
        for f in 0..<frames {
            g += step
            let l = s[f * inCh], r = inCh > 1 ? s[f * inCh + 1] : l
            peak.pointee = max(peak.pointee, abs(l))
            if outCh == 1 {
                d[f] = (l + r) * 0.5 * g
            } else {
                d[f * outCh] = l * g
                d[f * outCh + 1] = r * g
            }
        }
        current.pointee = target
    }
}

private struct CoreAudioError: LocalizedError {
    let status: OSStatus, step: String
    var errorDescription: String? { "\(step): OSStatus \(status)" }
}

private func check(_ status: OSStatus, _ step: String) throws {
    guard status == noErr else { throw CoreAudioError(status: status, step: step) }
}
