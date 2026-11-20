import AppKit

enum NyxWatchBrandIcon {
    static func draw(in rect: NSRect, foreground: NSColor = .white, monochrome: Bool = false) {
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.minX + x * rect.width / 100, y: rect.maxY - y * rect.height / 100)
        }

        let perimeter = NSBezierPath()
        perimeter.move(to: point(68, 18))
        perimeter.line(to: point(28, 18))
        perimeter.curve(to: point(18, 28), controlPoint1: point(21.3333, 18), controlPoint2: point(18, 21.3333))
        perimeter.line(to: point(18, 72))
        perimeter.curve(to: point(28, 82), controlPoint1: point(18, 78.6667), controlPoint2: point(21.3333, 82))
        perimeter.line(to: point(72, 82))
        perimeter.curve(to: point(82, 72), controlPoint1: point(78.6667, 82), controlPoint2: point(82, 78.6667))
        perimeter.line(to: point(82, 40))
        perimeter.lineWidth = rect.width * 0.07
        perimeter.lineCapStyle = .round
        perimeter.lineJoinStyle = .round
        foreground.setStroke()
        perimeter.stroke()

        let monogram = NSBezierPath()
        monogram.move(to: point(34, 64))
        monogram.line(to: point(34, 36))
        monogram.line(to: point(66, 64))
        monogram.line(to: point(66, 36))
        monogram.lineWidth = rect.width * 0.07
        monogram.lineJoinStyle = .round
        monogram.stroke()

        let center = point(82, 18)
        let radius = rect.width * 0.09
        let signal = NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2))
        let cherry = NSColor(calibratedRed: 220 / 255, green: 29 / 255, blue: 46 / 255, alpha: 1)
        (monochrome ? foreground : cherry).setFill()
        signal.fill()
    }

    static func image(size: CGFloat, template: Bool = false) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            draw(in: rect, foreground: template ? .black : .white, monochrome: template)
            return true
        }
        image.isTemplate = template
        image.accessibilityDescription = "NyxWatch"
        return image
    }
}
