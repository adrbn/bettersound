import AppKit
import ApplicationServices
import SwiftUI

/// Makes the BetterSound control in Control Center look and act like Apple's Sound module:
/// while Control Center is open, a "Sound" tile with a live slider is drawn exactly over our
/// control, and clicking it opens the mixer in place of Control Center.
/// Needs Accessibility, used only to read Control Center's layout.
@MainActor
final class ControlCenterHook {
    private let mixer: Mixer
    private let openMixer: (NSRect) -> Void
    private var tile: NSPanel?
    private var poll: Timer?
    private var clickMonitor: Any?

    init(mixer: Mixer, openMixer: @escaping (NSRect) -> Void) {
        self.mixer = mixer
        self.openMixer = openMixer
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func start() {
        // Control Center opens on a click (menu bar item or keyboard shortcut is rare): look for it right after.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] _ in
            MainActor.assumeIsolated { self?.watch() }
        }
    }

    /// Track Control Center for a short while after each click; stop once it's closed.
    private func watch() {
        guard Self.isTrusted, poll == nil else { return }
        poll = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.sync() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            if self?.tile == nil { self?.stopWatching() }
        }
    }

    private func stopWatching() {
        poll?.invalidate()
        poll = nil
        tile?.orderOut(nil)
        tile = nil
    }

    private func sync() {
        guard let cc = ControlCenterAX.openWindow(), let control = ControlCenterAX.ourControl(in: cc.element) else {
            if tile != nil { stopWatching() }
            return
        }
        let frame = control.cocoaFrame
        let panel = tile ?? makeTile()
        tile = panel
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        (panel.contentView as? NSHostingView<SoundTile>)?.rootView.ccFrame = cc.cocoaFrame
        panel.orderFrontRegardless()
    }

    private func makeTile() -> NSPanel {
        let p = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        p.level = .screenSaver
        p.backgroundColor = .clear
        p.hasShadow = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.contentView = NSHostingView(rootView: SoundTile(mixer: mixer, ccFrame: .zero) { [weak self] ccFrame in
            self?.stopWatching()
            self?.openMixer(ccFrame)
        })
        return p
    }
}

/// Stand-in for Apple's Sound module: title opens the mixer, slider sets the master volume.
struct SoundTile: View {
    @ObservedObject var mixer: Mixer
    var ccFrame: NSRect
    var open: (NSRect) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Sound").font(.system(size: 13, weight: .semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { open(ccFrame) }
            CapsuleSlider(value: mixer.master, leading: mixer.master == 0 ? "speaker.slash.fill" : "speaker.fill", height: 22) {
                mixer.setMaster($0)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(.regular, in: .rect(cornerRadius: 18))
    }
}

// MARK: - Accessibility reading of Control Center

struct AXNode {
    let element: AXUIElement
    let frame: CGRect   // AX coordinates: origin top-left of the primary screen

    var cocoaFrame: NSRect {
        let h = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: frame.minX, y: h - frame.maxY, width: frame.width, height: frame.height)
    }
}

enum ControlCenterAX {
    static let bundleID = "com.apple.controlcenter"
    /// Our control's AX label/identifier contains one of these.
    static let markers = ["bettersound"]

    static func attr(_ e: AXUIElement, _ name: String) -> AnyObject? {
        var v: AnyObject?
        return AXUIElementCopyAttributeValue(e, name as CFString, &v) == .success ? v : nil
    }

    static func frame(_ e: AXUIElement) -> CGRect? {
        var p = CGPoint.zero, s = CGSize.zero
        guard let pv = attr(e, kAXPositionAttribute), let sv = attr(e, kAXSizeAttribute) else { return nil }
        AXValueGetValue(pv as! AXValue, .cgPoint, &p)
        AXValueGetValue(sv as! AXValue, .cgSize, &s)
        return CGRect(origin: p, size: s)
    }

    static var app: AXUIElement? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
            .map { AXUIElementCreateApplication($0.processIdentifier) }
    }

    /// The open Control Center panel (the biggest Control Center window that isn't the menu bar).
    static func openWindow() -> AXNode? {
        guard let app else { return nil }
        let windows = (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? []
        return windows.compactMap { w in frame(w).map { AXNode(element: w, frame: $0) } }
            .filter { $0.frame.height > 100 }
            .max { $0.frame.height < $1.frame.height }
    }

    static func ourControl(in root: AXUIElement) -> AXNode? {
        var found: AXNode?
        walk(root, depth: 0) { e in
            let text = [kAXDescriptionAttribute, kAXTitleAttribute, kAXIdentifierAttribute, kAXHelpAttribute]
                .compactMap { attr(e, $0) as? String }.joined(separator: " ").lowercased()
            guard markers.contains(where: text.contains), let f = frame(e) else { return false }
            found = AXNode(element: e, frame: f)
            return true
        }
        return found
    }

    /// Depth-first; stops when `visit` returns true.
    @discardableResult
    static func walk(_ e: AXUIElement, depth: Int, _ visit: (AXUIElement) -> Bool) -> Bool {
        if visit(e) { return true }
        guard depth < 12 else { return false }
        for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] where walk(c, depth: depth + 1, visit) {
            return true
        }
        return false
    }

    /// Debug: `BetterSound --dump-cc` opens Control Center and writes its AX tree to /tmp/bettersound-cc.txt.
    static func dump() {
        guard let app else { return }
        if let bar = attr(app, kAXExtrasMenuBarAttribute) {
            for c in (attr(bar as! AXUIElement, kAXChildrenAttribute) as? [AXUIElement]) ?? []
            where (attr(c, kAXIdentifierAttribute) as? String) == "com.apple.menuextra.controlcenter" {
                AXUIElementPerformAction(c, kAXPressAction as CFString)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            var out = "trusted: \(AXIsProcessTrusted())\n"
            func line(_ e: AXUIElement, _ d: Int) {
                let keys = [kAXRoleAttribute, kAXSubroleAttribute, kAXDescriptionAttribute, kAXTitleAttribute, kAXIdentifierAttribute]
                let vals = keys.map { (attr(e, $0) as? String) ?? "" }.joined(separator: " | ")
                out += String(repeating: "  ", count: d) + vals + " \(frame(e).map { "\($0)" } ?? "")\n"
                guard d < 12 else { return }
                for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { line(c, d + 1) }
            }
            for w in (attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [] { line(w, 0) }
            try? out.write(toFile: "/tmp/bettersound-cc.txt", atomically: true, encoding: .utf8)
        }
    }
}
