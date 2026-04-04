#!/usr/bin/swift

import AppKit
import Foundation

let arguments = CommandLine.arguments

guard arguments.count == 2 else {
    fputs("Usage: generate-dmg-background.swift <output-png-path>\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: arguments[1])
let canvasSize = CGSize(width: 1280, height: 720)
let rect = CGRect(origin: .zero, size: canvasSize)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Unable to create bitmap context.\n", stderr)
    exit(1)
}

bitmap.size = canvasSize

guard
    let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fputs("Unable to create graphics context.\n", stderr)
    exit(1)
}

let context = graphicsContext.cgContext

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

context.setAllowsAntialiasing(true)
context.setShouldAntialias(true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1.0) -> NSColor {
    NSColor(calibratedRed: red / 255.0, green: green / 255.0, blue: blue / 255.0, alpha: alpha)
}

func drawLinearBackground() {
    let gradient = NSGradient(colors: [
        color(250, 247, 241),
        color(239, 243, 249)
    ]) ?? NSGradient(starting: color(250, 247, 241), ending: color(239, 243, 249))!

    gradient.draw(in: NSBezierPath(rect: rect), angle: -12)
}

func drawSoftGlow(center: CGPoint, radius: CGFloat, color glowColor: NSColor) {
    context.saveGState()

    let colors = [glowColor.withAlphaComponent(0.22).cgColor, glowColor.withAlphaComponent(0.0).cgColor] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    guard
        let rgb = CGColorSpace(name: CGColorSpace.sRGB),
        let gradient = CGGradient(colorsSpace: rgb, colors: colors, locations: locations)
    else {
        context.restoreGState()
        return
    }

    context.drawRadialGradient(
        gradient,
        startCenter: center,
        startRadius: 0,
        endCenter: center,
        endRadius: radius,
        options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
    )

    context.restoreGState()
}

func drawRing(center: CGPoint, radius: CGFloat, strokeColor: NSColor, lineWidth: CGFloat) {
    let ringRect = CGRect(
        x: center.x - radius,
        y: center.y - radius,
        width: radius * 2,
        height: radius * 2
    )

    let path = NSBezierPath(ovalIn: ringRect)
    path.lineWidth = lineWidth
    strokeColor.setStroke()
    path.stroke()
}

func drawTickMarks(center: CGPoint, radius: CGFloat, color tickColor: NSColor, lineWidth: CGFloat) {
    context.saveGState()
    context.setLineCap(.round)
    context.setStrokeColor(tickColor.cgColor)
    context.setLineWidth(lineWidth)

    for marker in 0..<4 {
        let angle = CGFloat(marker) * .pi / 2.0 - (.pi / 2.0)
        let start = CGPoint(
            x: center.x + cos(angle) * (radius - 16),
            y: center.y + sin(angle) * (radius - 16)
        )
        let end = CGPoint(
            x: center.x + cos(angle) * (radius - 34),
            y: center.y + sin(angle) * (radius - 34)
        )
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
    }

    context.restoreGState()
}

func drawConnector() {
    let path = NSBezierPath()
    path.move(to: CGPoint(x: 360, y: 365))
    path.curve(
        to: CGPoint(x: 924, y: 365),
        controlPoint1: CGPoint(x: 520, y: 428),
        controlPoint2: CGPoint(x: 760, y: 302)
    )

    context.saveGState()
    context.setLineCap(.round)
    context.setLineWidth(10)
    context.addPath(path.cgPath)
    context.replacePathWithStrokedPath()
    context.clip()

    let colors = [
        color(247, 181, 45, 0.22).cgColor,
        color(103, 132, 194, 0.18).cgColor
    ] as CFArray
    let locations: [CGFloat] = [0.0, 1.0]

    if
        let rgb = CGColorSpace(name: CGColorSpace.sRGB),
        let gradient = CGGradient(colorsSpace: rgb, colors: colors, locations: locations)
    {
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: 320, y: 410),
            end: CGPoint(x: 960, y: 320),
            options: []
        )
    }

    context.restoreGState()

    context.saveGState()
    context.setLineCap(.round)
    context.setStrokeColor(color(255, 255, 255, 0.55).cgColor)
    context.setLineWidth(2.5)
    context.addPath(path.cgPath)
    context.strokePath()
    context.restoreGState()
}

func drawOrbitalDots() {
    let dots: [(CGPoint, CGFloat, NSColor)] = [
        (CGPoint(x: 524, y: 420), 6, color(247, 181, 45, 0.5)),
        (CGPoint(x: 668, y: 348), 5, color(111, 141, 204, 0.44)),
        (CGPoint(x: 760, y: 384), 4, color(17, 24, 39, 0.12))
    ]

    for (center, radius, fillColor) in dots {
        fillColor.setFill()
        NSBezierPath(ovalIn: CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )).fill()
    }
}

func drawInsetFrame() {
    let frameRect = rect.insetBy(dx: 24, dy: 24)
    let frame = NSBezierPath(roundedRect: frameRect, xRadius: 26, yRadius: 26)
    color(255, 255, 255, 0.55).setStroke()
    frame.lineWidth = 3
    frame.stroke()
}

drawLinearBackground()
drawSoftGlow(center: CGPoint(x: 304, y: 360), radius: 238, color: color(247, 181, 45))
drawSoftGlow(center: CGPoint(x: 976, y: 360), radius: 232, color: color(105, 135, 200))
drawConnector()
drawRing(center: CGPoint(x: 300, y: 360), radius: 134, strokeColor: color(17, 24, 39, 0.12), lineWidth: 10)
drawRing(center: CGPoint(x: 982, y: 360), radius: 122, strokeColor: color(247, 181, 45, 0.22), lineWidth: 8)
drawTickMarks(center: CGPoint(x: 300, y: 360), radius: 134, color: color(17, 24, 39, 0.16), lineWidth: 4)
drawTickMarks(center: CGPoint(x: 982, y: 360), radius: 122, color: color(247, 181, 45, 0.18), lineWidth: 3)
drawOrbitalDots()
drawInsetFrame()
NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode DMG background image.\n", stderr)
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
    fputs("Failed to write DMG background image: \(error)\n", stderr)
    exit(1)
}
