import AppKit
import Combine
import ServiceManagement
import Sparkle
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
    private let updater = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

    func applicationDidFinishLaunching(_ note: Notification) {
        AppDelegate.shared = self
        // First launch: take Apple's Sound slot in the menu bar (its own preferred position), and open at login.
        let slot = "NSStatusItem Preferred Position BetterSound"
        if UserDefaults.standard.object(forKey: slot) == nil {
            let apple = UserDefaults(suiteName: "com.apple.controlcenter")?.object(forKey: "NSStatusItem Preferred Position Sound")
            UserDefaults.standard.set(apple ?? 380, forKey: slot)
            try? SMAppService.mainApp.register()
        }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "BetterSound"
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
        if CommandLine.arguments.contains("--extras") {
            // Debug: list Control Center's menu bar items and where ours sits.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [self] in
                var out = "ours: \(statusItem.button?.window?.frame ?? .zero) visible=\(statusItem.isVisible)\n"
                if let app = ControlCenterAX.app, let bar = ControlCenterAX.attr(app, kAXExtrasMenuBarAttribute) {
                    for c in (ControlCenterAX.attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? [] {
                        out += "\((ControlCenterAX.attr(c, kAXIdentifierAttribute) as? String) ?? "") \(ControlCenterAX.frame(c) ?? .zero)\n"
                    }
                }
                try? out.write(toFile: "/tmp/bettersound-extras.txt", atomically: true, encoding: .utf8)
            }
        }
        if CommandLine.arguments.contains("--diag") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [mixer] in
                let procs = Audio.processes().map { "\($0.pid)->\(Audio.owningApp($0.pid)?.bundleIdentifier ?? "nil") playing=\($0.isPlaying)" }
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
        // bettersound://output/<device name>: same as picking it in the panel (scripts, tests).
        if let url = urls.first(where: { $0.host == "output" }), let dev = mixer.devices.first(where: { $0.name == url.lastPathComponent }) {
            mixer.selectDefault(dev)
        }
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
            let login = menu.addItem(withTitle: String(localized: "Open at Login"), action: #selector(toggleLogin), keyEquivalent: "")
            login.target = self
            login.state = SMAppService.mainApp.status == .enabled ? .on : .off
            menu.addItem(.separator())
            let update = menu.addItem(withTitle: String(localized: "Check for Updates…"), action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)), keyEquivalent: "")
            update.target = updater
            for (title, url) in [(String(localized: "BetterSound on GitHub"), "https://github.com/adrbn/bettersound"),
                                 (String(localized: "Support on Ko-fi"), "https://ko-fi.com/adrbn")] {
                let item = menu.addItem(withTitle: title, action: #selector(openLink(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = URL(string: url)
            }
            menu.addItem(.separator())
            menu.addItem(withTitle: String(localized: "Quit BetterSound"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle(below: statusItem.button?.window)
        }
    }

    @objc private func openLink(_ item: NSMenuItem) {
        if let url = item.representedObject as? URL { NSWorkspace.shared.open(url) }
    }

    @objc private func toggleLogin() {
        let app = SMAppService.mainApp
        try? app.status == .enabled ? app.unregister() : app.register()
    }

    func toggle(below anchor: NSWindow?) {
        panel.isVisible ? hide() : show(below: anchor)
    }

    private func show(below anchor: NSWindow?) {
        mixer.refresh()
        mixer.refreshBattery()
        let size = panel.contentView!.fittingSize
        let screen = anchor?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var x = visible.maxX - size.width - 10
        // Like a menu: left edge under the menu bar icon.
        if let anchor { x = min(max(anchor.frame.minX - 6, visible.minX + 6), visible.maxX - size.width - 6) }
        // Just under the menu bar, even when a full-screen app hides it.
        topY = screen.frame.maxY - NSStatusBar.system.thickness - 6
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
