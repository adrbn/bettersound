import AppKit
import SwiftUI

/// Copy of Apple's Sound menu (menu bar / Control Center), with an Apps section added.
struct MixerView: View {
    @ObservedObject var mixer: Mixer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sound").font(.system(size: 13, weight: .bold))
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                Slider(value: Binding(get: { Double(mixer.master) }, set: { mixer.setMaster(Float($0)) }))
                Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
            }
            .font(.system(size: 13))
            .disabled(!mixer.hasMaster)
            .padding(.horizontal, 14).padding(.bottom, 8)

            if mixer.permission != .granted {
                separator
                permissionRow
            } else if !mixer.apps.isEmpty {
                separator
                header("Apps")
                ForEach(mixer.apps) { appRow($0) }
                    .padding(.horizontal, 14).padding(.vertical, 3)
                Spacer().frame(height: 6)
            }

            separator
            header("Output")
            ForEach(mixer.devices) { device in
                DeviceRow(device: device, selected: device.id == mixer.defaultDeviceID) {
                    mixer.selectDefault(device)
                }
            }
            Spacer().frame(height: 4)

            separator
            MenuRow(title: "Sound Settings…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!)
            }
            .padding(.bottom, 6)
        }
        .frame(width: 300)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
    }

    private var separator: some View {
        Divider().padding(.horizontal, 14).padding(.vertical, 4)
    }

    private func header(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14).padding(.top, 2).padding(.bottom, 4)
    }

    private func appRow(_ app: AppRow) -> some View {
        let muted = mixer.isMuted(app.id)
        let route = mixer.route(app.id).flatMap { uid in mixer.devices.first { $0.uid == uid } }
        return HStack(spacing: 8) {
            Button { mixer.toggleMute(app.id) } label: {
                Image(nsImage: app.icon).resizable().frame(width: 22, height: 22)
                    .opacity(muted ? 0.35 : 1)
            }
            .buttonStyle(.plain)
            .help(app.name)

            Slider(value: Binding(get: { Double(muted ? 0 : mixer.volume(app.id)) },
                                  set: { mixer.setVolume(app.id, Float($0)) }))

            Menu {
                Picker("Output", selection: Binding(
                    get: { mixer.route(app.id) ?? "" },
                    set: { mixer.setRoute(app.id, $0.isEmpty ? nil : $0) })) {
                    Text("System Output").tag("")
                    ForEach(mixer.devices) { Text($0.name).tag($0.uid) }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: route?.symbol ?? "speaker.wave.3.fill")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .foregroundStyle(.secondary)
        }
    }

    private var permissionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Per-app volume needs access to system audio. Nothing is recorded.")
                .font(.system(size: 12)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Allow") { mixer.requestPermission() }.controlSize(.small)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
    }
}

/// Highlights on hover like a menu item.
private struct MenuRow<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 9).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.1) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 5)
        .onHover { hover = $0 }
    }
}

extension MenuRow where Label == Text {
    init(title: LocalizedStringKey, action: @escaping () -> Void) {
        self.action = action
        self.label = Text(title).font(.system(size: 13))
    }
}

private struct DeviceRow: View {
    let device: OutputDevice
    let selected: Bool
    let action: () -> Void

    var body: some View {
        MenuRow(action: action) {
            HStack(spacing: 10) {
                Image(systemName: device.symbol)
                    .font(.system(size: 12))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(selected ? Color.accentColor : Color.primary.opacity(0.1)))
                    .foregroundStyle(selected ? .white : .primary)
                Text(device.name).font(.system(size: 13)).lineLimit(1)
            }
        }
    }
}
