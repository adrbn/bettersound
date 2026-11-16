// Renders the SF Symbols the README art uses (the same ones the app shows) to PNG.
// swift docs/assets/symbols.swift docs/assets/readme-src
import AppKit
let out = CommandLine.arguments[1]
let names = ["airpods.pro", "speaker.wave.2.fill", "laptopcomputer", "display", "wifi", "battery.75percent", "magnifyingglass", "switch.2"]
for name in names {
    for (suffix, color) in [("w", NSColor.white), ("b", NSColor.black)] {
        let config = NSImage.SymbolConfiguration(pointSize: 64, weight: .regular).applying(.init(paletteColors: [color]))
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { continue }
        let rep = NSBitmapImageRep(data: img.tiffRepresentation!)!
        try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/sym-\(name)-\(suffix).png"))
    }
}
