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

    func applicationDidFinishLaunching(_ note: Notification) {
        AppDelegate.shared = self
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "BetterSound")
        statusItem.button?.target = self
        statusItem.button?.action = #selector(statusClicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: MixerView(mixer: mixer))

        // Rows come and go: keep the panel's top edge pinned while its height follows the content.
        resize = mixer.objectWillChange.receive(on: RunLoop.main).sink { [weak self] _ in
            MainActor.assumeIsolated { self?.fitHeight() }
        }
        NotificationCenter.default.addObserver(forName: .showBetterSound, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.toggle(below: nil) }
        }
        if CommandLine.arguments.contains("--show") { show(below: nil) }
    }

    func application(_ app: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.host == "show" }) { toggle(below: nil) }
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(withTitle: "Quit BetterSound", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            toggle(below: statusItem.button?.window)
        }
    }

    /// From the Control Center control (no anchor): open where Control Center opens, top right.
    func toggle(below anchor: NSWindow?) {
        panel.isVisible ? hide() : show(below: anchor)
    }

    private func show(below anchor: NSWindow?) {
        mixer.refresh()
        let size = panel.contentView!.fittingSize
        let screen = anchor?.screen ?? NSScreen.main ?? NSScreen.screens[0]
        let visible = screen.visibleFrame
        var x = visible.maxX - size.width - 10
        if let anchor { x = min(max(anchor.frame.midX - size.width / 2, visible.minX + 10), x) }
        topY = visible.maxY - 6
        panel.setFrame(NSRect(x: x, y: topY - size.height, width: size.width, height: size.height), display: true)
        panel.orderFrontRegardless()

        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func fitHeight() {
        guard panel.isVisible else { return }
        let size = panel.contentView!.fittingSize
        guard size.height != panel.frame.height else { return }
        panel.setFrame(NSRect(x: panel.frame.minX, y: topY - size.height, width: size.width, height: size.height), display: true)
    }

    private func hide() {
        panel.orderOut(nil)
        if let outsideClick { NSEvent.removeMonitor(outsideClick) }
        outsideClick = nil
    }
}
