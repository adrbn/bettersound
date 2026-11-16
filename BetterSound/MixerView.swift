import AppKit
import SwiftUI

/// Same layout as the Sound module in Control Center, with an Apps section added.
struct MixerView: View {
    @ObservedObject var mixer: Mixer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sound").font(.system(size: 13, weight: .bold))
            CapsuleSlider(value: mixer.master, leading: speaker(mixer.master), trailing: "speaker.wave.3.fill") {
                mixer.setMaster($0)
            }
            .disabled(!mixer.hasMaster)
            .opacity(mixer.hasMaster ? 1 : 0.4)

            if mixer.permission != .granted {
                permissionRow
            } else if !mixer.apps.isEmpty {
                section("Apps")
                ForEach(mixer.apps) { appRow($0) }
            }

            section("Output")
            ForEach(mixer.devices) { device in
                DeviceRow(device: device, selected: device.id == mixer.defaultDeviceID) {
                    mixer.selectDefault(device)
                }
            }

            Divider().padding(.vertical, 2)
            Button("Sound Settings…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13))
        }
        .padding(14)
        .frame(width: 320)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func appRow(_ app: AppRow) -> some View {
        let muted = mixer.isMuted(app.id)
        let value = muted ? 0 : mixer.volume(app.id)
        return HStack(spacing: 8) {
            Button { mixer.toggleMute(app.id) } label: {
                Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                    .opacity(muted ? 0.4 : 1)
            }
            .buttonStyle(.plain)
            .help(muted ? "Unmute \(app.name)" : "Mute \(app.name)")

            CapsuleSlider(value: value, height: 22) { mixer.setVolume(app.id, $0) }

            Menu {
                Picker("Output", selection: Binding(
                    get: { mixer.route(app.id) ?? "" },
                    set: { mixer.setRoute(app.id, $0.isEmpty ? nil : $0) })) {
                    Text("System Output").tag("")
                    ForEach(mixer.devices) { Text($0.name).tag($0.uid) }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: mixer.route(app.id) == nil ? "speaker.wave.2" : "speaker.wave.2.circle.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Output for \(app.name)")
        }
    }

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Per-app volume needs access to system audio. Nothing is recorded.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack {
                Button("Allow") { mixer.requestPermission() }
                Button("Open Privacy Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AudioCapture")!)
                }
            }
            .controlSize(.small)
        }
        .padding(.top, 4)
    }

    private func speaker(_ v: Float) -> String {
        v == 0 ? "speaker.slash.fill" : "speaker.fill"
    }
}

/// Thick Control Center style slider.
struct CapsuleSlider: View {
    var value: Float
    var leading: String?
    var trailing: String?
    var height: CGFloat = 26
    var onChange: (Float) -> Void

    var body: some View {
        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.primary.opacity(0.12))
                    Capsule().fill(.white)
                        .frame(width: max(height, geo.size.width * CGFloat(value)))
                        .opacity(value == 0 ? 0.0 : 1)
                    if let leading {
                        Image(systemName: leading)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.55))
                            .padding(.leading, 8)
                    }
                }
                .contentShape(Capsule())
                .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                    onChange(Float(min(max(g.location.x / geo.size.width, 0), 1)))
                })
            }
            .frame(height: height)
            if let trailing {
                Image(systemName: trailing).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct DeviceRow: View {
    let device: OutputDevice
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: device.symbol)
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(selected ? Color.accentColor : Color.primary.opacity(0.1)))
                    .foregroundStyle(selected ? .white : .primary)
                Text(device.name).font(.system(size: 13))
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
