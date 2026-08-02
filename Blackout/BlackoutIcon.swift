import Cocoa

enum BlackoutIcon {
    static func image() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        NSColor.black.setStroke()
        let touchBar = NSBezierPath(
            roundedRect: NSRect(x: 1.5, y: 6, width: 15, height: 6),
            xRadius: 2.5,
            yRadius: 2.5
        )
        touchBar.lineWidth = 1.5
        touchBar.stroke()
        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: 4, y: 3.5))
        slash.line(to: NSPoint(x: 14, y: 14.5))
        slash.lineWidth = 2
        slash.lineCapStyle = .round
        slash.stroke()
        image.isTemplate = true
        return image
    }
}
