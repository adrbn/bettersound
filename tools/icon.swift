// Draws the app icon: a dark squircle with three mixer faders. `swift tools/icon.swift out.png`
import AppKit
let size: CGFloat = 1024, inset: CGFloat = 100, r: CGFloat = 185
let img = NSImage(size: NSSize(width: size, height: size))
img.lockFocus()
let tile = NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset)
NSGraphicsContext.current?.cgContext.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.35).cgColor)
let shape = NSBezierPath(roundedRect: tile, xRadius: r, yRadius: r)
NSColor.black.setFill(); shape.fill()
NSGraphicsContext.current?.cgContext.setShadow(offset: .zero, blur: 0, color: nil)
NSGradient(colors: [NSColor(white: 0.28, alpha: 1), NSColor(white: 0.10, alpha: 1)])!.draw(in: shape, angle: -90)
let knobs: [CGFloat] = [0.62, 0.30, 0.80]   // fader positions, bottom to top
let accent = NSColor(red: 0.98, green: 0.76, blue: 0.20, alpha: 1)
for (i, k) in knobs.enumerated() {
    let x = tile.minX + tile.width * CGFloat(i + 1) / 4
    let bottom = tile.minY + 170, top = tile.maxY - 170
    let track = NSRect(x: x - 14, y: bottom, width: 28, height: top - bottom)
    NSColor(white: 1, alpha: 0.16).setFill(); NSBezierPath(roundedRect: track, xRadius: 14, yRadius: 14).fill()
    let y = bottom + (top - bottom) * k
    accent.setFill(); NSBezierPath(roundedRect: NSRect(x: x - 14, y: bottom, width: 28, height: y - bottom), xRadius: 14, yRadius: 14).fill()
    NSColor.white.setFill(); NSBezierPath(ovalIn: NSRect(x: x - 52, y: y - 52, width: 104, height: 104)).fill()
}
img.unlockFocus()
let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
