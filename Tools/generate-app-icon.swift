#!/usr/bin/swift

import AppKit
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 2 else {
    fputs("Usage: generate-app-icon.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let canvasSize = CGSize(width: 1024, height: 1024)

let image = NSImage(size: canvasSize)
image.lockFocus()

guard let context = NSGraphicsContext.current?.cgContext else {
    fputs("Unable to create graphics context.\n", stderr)
    exit(1)
}

let rect = CGRect(origin: .zero, size: canvasSize)
context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
}

func fillRoundedRect(_ rect: CGRect, radius: CGFloat, colors: [NSColor], angle: CGFloat) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    path.addClip()
    let gradient = NSGradient(colors: colors) ?? NSGradient(starting: colors[0], ending: colors[1])!
    gradient.draw(in: path, angle: angle)
}

func drawClock(
    center: CGPoint,
    radius: CGFloat,
    fillColor: NSColor?,
    rimColor: NSColor,
    tickColor: NSColor?,
    handColor: NSColor,
    accentColor: NSColor,
    hour: CGFloat,
    minute: CGFloat,
    shadowColor: NSColor? = nil
) {
    let faceRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )

    if let shadowColor {
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -radius * 0.08), blur: radius * 0.16, color: shadowColor.cgColor)
        if let fillColor {
            fillColor.setFill()
            NSBezierPath(ovalIn: faceRect).fill()
        }
        context.restoreGState()
    }

    if let fillColor {
        fillColor.setFill()
        NSBezierPath(ovalIn: faceRect).fill()
    }

    let rimPath = NSBezierPath(ovalIn: faceRect.insetBy(dx: radius * 0.02, dy: radius * 0.02))
    rimColor.setStroke()
    rimPath.lineWidth = max(6, radius * 0.05)
    rimPath.stroke()

    if let tickColor {
        let tickLength = radius * 0.1
        let tickInset = radius * 0.18
        context.saveGState()
        context.setLineCap(.round)
        context.setStrokeColor(tickColor.cgColor)
        context.setLineWidth(max(4, radius * 0.03))
        for marker in 0..<4 {
            let angle = CGFloat(marker) * .pi / 2.0 - (.pi / 2.0)
            let start = CGPoint(
                x: center.x + cos(angle) * (radius - tickInset),
                y: center.y + sin(angle) * (radius - tickInset)
            )
            let end = CGPoint(
                x: center.x + cos(angle) * (radius - tickInset - tickLength),
                y: center.y + sin(angle) * (radius - tickInset - tickLength)
            )
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
        context.restoreGState()
    }

    func handEndpoint(length: CGFloat, angle: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + cos(angle) * length,
            y: center.y + sin(angle) * length
        )
    }

    let minuteAngle = ((minute / 60.0) * 2.0 * .pi) - (.pi / 2.0)
    let hourAngle = (((hour + minute / 60.0) / 12.0) * 2.0 * .pi) - (.pi / 2.0)

    context.saveGState()
    context.setLineCap(.round)

    context.setStrokeColor(accentColor.cgColor)
    context.setLineWidth(max(8, radius * 0.052))
    context.move(to: center)
    context.addLine(to: handEndpoint(length: radius * 0.64, angle: minuteAngle))
    context.strokePath()

    context.setStrokeColor(handColor.cgColor)
    context.setLineWidth(max(10, radius * 0.072))
    context.move(to: center)
    context.addLine(to: handEndpoint(length: radius * 0.45, angle: hourAngle))
    context.strokePath()

    accentColor.setFill()
    NSBezierPath(ovalIn: CGRect(
        x: center.x - radius * 0.085,
        y: center.y - radius * 0.085,
        width: radius * 0.17,
        height: radius * 0.17
    )).fill()
    context.restoreGState()
}

fillRoundedRect(
    rect.insetBy(dx: 36, dy: 36),
    radius: 230,
    colors: [
        color(17, 24, 39),
        color(24, 36, 62)
    ],
    angle: -50
)

let framePath = NSBezierPath(roundedRect: rect.insetBy(dx: 36, dy: 36), xRadius: 230, yRadius: 230)
color(255, 255, 255, 0.08).setStroke()
framePath.lineWidth = 5
framePath.stroke()

drawClock(
    center: CGPoint(x: 420, y: 448),
    radius: 240,
    fillColor: color(245, 247, 251),
    rimColor: color(255, 255, 255, 0.92),
    tickColor: color(31, 41, 55, 0.32),
    handColor: color(15, 23, 42),
    accentColor: color(247, 181, 45),
    hour: 7,
    minute: 10,
    shadowColor: color(7, 15, 28, 0.24)
)

drawClock(
    center: CGPoint(x: 664, y: 662),
    radius: 156,
    fillColor: nil,
    rimColor: color(247, 181, 45),
    tickColor: nil,
    handColor: color(245, 247, 251),
    accentColor: color(247, 181, 45),
    hour: 2,
    minute: 20
)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Unable to encode icon image.\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true,
        attributes: nil
    )
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Failed to write icon image: \(error)\n", stderr)
    exit(1)
}
