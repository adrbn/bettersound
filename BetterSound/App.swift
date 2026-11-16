import AppKit
import Combine
import SwiftUI

@main
struct BetterSoundApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) weak var shared: AppDelegate?

    private let mixer = Mixer()
    private var statusItem: NSStatusItem!
    private var panel: NSPanel!
    private var outsideClick: Any?
    private var topY: CGFloat = 0
    private var resize: AnyCancellable?
    private var hook: ControlCenterHook?

    func applicationDidFinishLaunching(_ note: Notification) {
        AppDelegate.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        updateIcon()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        panel = KeyPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let host = NSHostingView(rootView: MixerView(mixer: mixer))
        // Round the window itself, or its shadow and backing show square corners.
        host.wantsLayer = true
        host.layer?.cornerRadius = 14
        host.layer?.masksToBounds = true
        panel.contentView = host

        // Rows come and go: keep the panel's top edge pinned while its height follows the content.
        resize = mixer.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.fitHeight(); self?.updateIcon() }
        }
        hook = ControlCenterHook { [weak self] ccFrame in self?.show(over: ccFrame) }
        hook?.start()
        if !ControlCenterHook.isTrusted { ControlCenterHook.requestTrust() }
        AppleSoundItem.hide()

        if CommandLine.arguments.contains("--show") { show(below: nil) }
        if CommandLine.arguments.contains("--dump-cc") { ControlCenterAX.dump() }
        if CommandLine.arguments.contains("--diag") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [mixer] in
                let procs = Audio.processes().map { "\($0.pid)->\(Audio.responsiblePID($0.pid)) playing=\($0.isPlaying)" }
                let text = "permission: \(AudioPermission.status)\napps: \(mixer.apps.map(\.id))\n\(mixer.debugState)\nprocs: \(procs)\n"
                try? text.write(toFile: "/tmp/bettersound-diag.txt", atomically: true, encoding: .utf8)
            }
        }
    }

    func applicationWillTerminate(_ note: Notification) {
        AppleSoundItem.restore()
    }

    /// Same icon as Apple's Sound item: the output device, or a speaker showing the level.
    private func updateIcon() {
        DispatchQueue.main.async { [self] in
            let name = mixer.menuBarSymbol
            guard statusItem.button?.image?.accessibilityDescription != name else { return }
            let img = NSImage(systemSymbolName: name, accessibilityDescription: name)
            img?.isTemplate = true
            statusItem.button?.image = img
        }
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.host == "show" }) { toggle(below: nil) }
    }

    /// Launching it again (Spotlight, Dock) opens the panel: the menu bar icon can be hidden
    /// behind the notch when the bar is full.
    func applicationShouldHandleReopen(_ app: NSApplication, hasVisibleWindows: Bool) -> Bool {
        toggle(below: nil)
        return false
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: String(localized: "Quit BetterSound"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle(below: statusItem.button?.window)
        }
    }

    func toggle(below anchor: NSWindow?) {
        panel.isVisible ? hide() : show(below: anchor)
    }

    private func show(below anchor: NSWindow?) {
        mixer.refresh()
        let size = panel.contentView!.fittingSize
        let screen = anchor?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var x = visible.maxX - size.width - 10
        // Like a menu: left edge under the menu bar icon.
        if let anchor { x = min(max(anchor.frame.minX - 6, visible.minX + 6), visible.maxX - size.width - 6) }
        topY = visible.maxY - 4
        panel.setFrame(NSRect(x: x, y: topY - size.height, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()
        panel.makeKey()   // active look: sliders filled with the accent colour
        panel.invalidateShadow()

        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    /// Opened from Control Center's Sound module: take Control Center's place, like Apple's Sound view.
    private func show(over ccFrame: NSRect) {
        show(below: nil)
        let size = panel.frame.size
        topY = ccFrame.maxY
        panel.setFrameOrigin(NSPoint(x: ccFrame.maxX - size.width, y: topY - size.height))
    }

    private func fitHeight() {
        guard panel.isVisible else { return }
        let size = panel.contentView!.fittingSize
        guard size.height != panel.frame.height else { return }
        panel.setFrame(NSRect(x: panel.frame.minX, y: topY - size.height, width: size.width, height: size.height), display: true)
        panel.invalidateShadow()
    }

    private func hide() {
        panel.orderOut(nil)
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        outsideClick = nil
    }
}

/// Hides Apple's Sound menu bar item while BetterSound runs (its own item replaces it), restores it on quit.
enum AppleSoundItem {
    private static let saved = "appleSoundVisibility"

    static func hide() {
        let current = run("read", "Sound").trimmingCharacters(in: .whitespacesAndNewlines)
        guard current != "8" else { return }
        UserDefaults.standard.set(current.isEmpty ? "18" : current, forKey: saved)
        run("write", "Sound", "-int", "8")
        reloadControlCenter()
    }

    static func restore() {
        guard let value = UserDefaults.standard.string(forKey: saved) else { return }
        run("write", "Sound", "-int", value)
        UserDefaults.standard.removeObject(forKey: saved)
        reloadControlCenter()
    }

    @discardableResult
    private static func run(_ args: String...) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        p.arguments = ["-currentHost", args[0], "com.apple.controlcenter"] + args.dropFirst()
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
        return String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    }

    /// Control Center reads this setting at launch; it relaunches itself right away.
    private static func reloadControlCenter() {
        NSRunningApplication.runningApplications(withBundleIdentifier: ControlCenterAX.bundleID).forEach { $0.terminate() }
    }
}

/// A non-activating panel that still becomes key, so its controls draw in their active state.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}
