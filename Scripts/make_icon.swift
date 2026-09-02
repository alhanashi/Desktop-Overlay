#!/usr/bin/env swift
// Generates the AppIcon PNG set (no design tools needed).
//   swift Scripts/make_icon.swift
// Re-run whenever you want to tweak the icon; output goes straight into the
// asset catalog.

import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "DesktopOverlay/Resources/Assets.xcassets/AppIcon.appiconset"

func makeIcon(_ side: CGFloat) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(side), pixelsHigh: Int(side),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: side, height: side)

    NSGraphicsContext.saveGraphicsState()
    let nsCtx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext

    // Rounded-rect background with a graphite vertical gradient.
    let inset = side * 0.055
    let rect = CGRect(x: inset, y: inset, width: side - 2 * inset, height: side - 2 * inset)
    let corner = side * 0.2237
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil))
    ctx.clip()
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space, colors: [
        CGColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1),
        CGColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1),
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: side), end: .zero, options: [])
    ctx.resetClip()

    // Gauge dial.
    let center = CGPoint(x: side * 0.5, y: side * 0.455)
    let radius = side * 0.27
    ctx.setLineCap(.round)

    ctx.setLineWidth(side * 0.055)
    ctx.setStrokeColor(CGColor(red: 0.86, green: 0.87, blue: 0.90, alpha: 0.92))
    ctx.addArc(center: center, radius: radius,
               startAngle: .pi * 220 / 180, endAngle: .pi * -40 / 180, clockwise: true)
    ctx.strokePath()

    // Needle (accent) pointing up-right.
    let angle = CGFloat.pi * 33 / 180
    ctx.setStrokeColor(CGColor(red: 0.29, green: 0.72, blue: 0.98, alpha: 1))
    ctx.setLineWidth(side * 0.036)
    ctx.move(to: center)
    ctx.addLine(to: CGPoint(x: center.x + cos(angle) * radius * 0.92,
                            y: center.y + sin(angle) * radius * 0.92))
    ctx.strokePath()

    // Hub.
    ctx.setFillColor(CGColor(red: 0.96, green: 0.96, blue: 0.97, alpha: 1))
    let hub = side * 0.032
    ctx.fillEllipse(in: CGRect(x: center.x - hub, y: center.y - hub, width: hub * 2, height: hub * 2))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let targets: [(String, CGFloat)] = [
    ("icon_16.png", 16), ("icon_16@2x.png", 32),
    ("icon_32.png", 32), ("icon_32@2x.png", 64),
    ("icon_128.png", 128), ("icon_128@2x.png", 256),
    ("icon_256.png", 256), ("icon_256@2x.png", 512),
    ("icon_512.png", 512), ("icon_512@2x.png", 1024),
]

let base = URL(fileURLWithPath: outDir)
for (name, side) in targets {
    try makeIcon(side).write(to: base.appendingPathComponent(name))
    print("wrote \(name) — \(Int(side))px")
}
