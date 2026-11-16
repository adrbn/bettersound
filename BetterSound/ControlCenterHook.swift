import AppKit
import ApplicationServices

/// Takes over Apple's Sound module in Control Center: a click on it (outside its slider)
/// is swallowed and the mixer opens in Control Center's place. The slider keeps working.
/// Needs Accessibility: to read Control Center's layout and to filter those clicks.
@MainActor
final class ControlCenterHook {
    private let open: (NSRect) -> Void
    private var tap: CFMachPort?
    private var target: (module: CGRect, passthrough: [CGRect], panel: CGRect)?
    private var swallowing = false

    init(open: @escaping (NSRect) -> Void) { self.open = open }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestTrust() {
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    func start() {
        guard tap == nil, Self.isTrusted else { return }
        let mask = CGEventMask(1 << CGEventType.leftMouseDown.rawValue) | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
                                eventsOfInterest: mask, callback: { _, type, event, ref in
            let hook = Unmanaged<ControlCenterHook>.fromOpaque(ref!).takeUnretainedValue()
            return MainActor.assumeIsolated { hook.handle(type, event) }
        }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        let p = event.location   // same top-left coordinates as AX
        if type == .leftMouseDown {
            // Our panel opens over Control Center's Sound tile: clicks on it are ours.
            let mouse = NSEvent.mouseLocation
            if NSApp.windows.contains(where: { $0.isVisible && $0.frame.contains(mouse) }) {
                target = nil
                return Unmanaged.passUnretained(event)
            }
            target = ControlCenterAX.soundModule()
            if let t = target, t.module.contains(p), !t.passthrough.contains(where: { $0.contains(p) }) {
                swallowing = true
                return nil
            }
        } else if swallowing {
            swallowing = false
            if let t = target { open(ControlCenterAX.cocoa(t.panel)) }
            return nil
        }
        return Unmanaged.passUnretained(event)
    }
}

// MARK: - Accessibility reading of Control Center

enum ControlCenterAX {
    static let bundleID = "com.apple.controlcenter"

    static func cocoa(_ r: CGRect) -> NSRect {
        let h = NSScreen.screens.first?.frame.height ?? 0
        return NSRect(x: r.minX, y: h - r.maxY, width: r.width, height: r.height)
    }

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

    /// The open Control Center panel: the tallest Control Center window.
    static func openWindow() -> (element: AXUIElement, frame: CGRect)? {
        guard let app else { return nil }
        return ((attr(app, kAXWindowsAttribute) as? [AXUIElement]) ?? [])
            .compactMap { w in frame(w).map { (w, $0) } }
            .filter { $0.1.height > 100 }
            .max { $0.1.height < $1.1.height }
    }

    /// Apple's Sound module, found by Control Center's own identifiers. The tile has no AX
    /// element of its own, so its frame is the title, slider and AirPlay button plus padding.
    /// `passthrough` are the parts that keep Apple's behaviour (slider, AirPlay).
    static func soundModule() -> (module: CGRect, passthrough: [CGRect], panel: CGRect)? {
        guard let win = openWindow() else { return nil }
        var found: [String: CGRect] = [:]
        var content = CGRect.null
        let ids = ["controlcenter-volume", "controlcenter-volume-slider", "controlcenter-airplay"]
        walk(win.element, parent: nil, depth: 0) { e, _ in
            if let id = attr(e, kAXIdentifierAttribute) as? String, ids.contains(id), let f = frame(e) { found[id] = f }
            if let id = attr(e, kAXIdentifierAttribute) as? String, id.hasPrefix("controlcenter-"), let f = frame(e) {
                content = content.union(f)
            }
            return false
        }
        guard let title = found["controlcenter-volume"], let slider = found["controlcenter-volume-slider"] else { return nil }
        let parts = [title, slider, found["controlcenter-airplay"]].compactMap { $0 }
        let tile = parts.reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -14, dy: -12)
        let pass = [slider.insetBy(dx: -4, dy: -8)] + [found["controlcenter-airplay"]].compactMap { $0 }
        // The visible Control Center panel: its controls plus the margin around them.
        return (tile, pass, content.insetBy(dx: -14, dy: -14))
    }

    /// Depth-first; stops when `visit` returns true.
    @discardableResult
    static func walk(_ e: AXUIElement, parent: AXUIElement?, depth: Int,
                     _ visit: (AXUIElement, AXUIElement?) -> Bool) -> Bool {
        if visit(e, parent) { return true }
        guard depth < 14 else { return false }
        for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] where walk(c, parent: e, depth: depth + 1, visit) {
            return true
        }
        return false
    }

    /// Debug: `BetterSound --dump-cc` waits (up to 2 min) for Control Center to open, then writes
    /// its AX tree to /tmp/bettersound-cc.txt.
    @MainActor
    static func dump(tries: Int = 600) {
        guard tries > 0 else { return }
        guard let w = openWindow() else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dump(tries: tries - 1) }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var out = ""
            func line(_ e: AXUIElement, _ d: Int) {
                let keys = [kAXRoleAttribute, kAXSubroleAttribute, kAXDescriptionAttribute, kAXTitleAttribute, kAXIdentifierAttribute, kAXHelpAttribute]
                let vals = keys.map { (attr(e, $0) as? String) ?? "" }.joined(separator: " | ")
                out += String(repeating: "  ", count: d) + vals + " \(frame(e).map { "\($0)" } ?? "")\n"
                guard d < 14 else { return }
                for c in (attr(e, kAXChildrenAttribute) as? [AXUIElement]) ?? [] { line(c, d + 1) }
            }
            line(w.element, 0)
            try? out.write(toFile: "/tmp/bettersound-cc.txt", atomically: true, encoding: .utf8)
        }
    }
}
