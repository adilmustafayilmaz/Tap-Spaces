#!/usr/bin/env swift
// Draws AppIcon.iconset for Tap Spaces.
//
// The mark is a 2×2 zone grid with one zone lit and ripples spreading from it —
// the app localising a tap to one quadrant of the table.
//
// Geometry is recomputed per size rather than downscaled from one master, so
// the 16pt version stays crisp instead of turning to mush. Below 40px the grid
// outlines and outer ripples are dropped; only the lit zone and a single ring
// survive, which is all that reads at that scale.

import AppKit
import Foundation

let outDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/AppIcon.iconset"

try? FileManager.default.createDirectory(atPath: outDir,
                                         withIntermediateDirectories: true)

// (filename, pixel size)
let targets: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

func rgb(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255, alpha: a)
}

/// Apple's rounded-rect ratio for app icons: the squircle fills ~82% of the
/// canvas, corner radius ~22.37% of its side.
let squircleInset: CGFloat = 0.086
let cornerRatio: CGFloat = 0.2237

func drawIcon(px: Int) -> Data {
    let n = CGFloat(px)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // ---- squircle -----------------------------------------------------
    let inset = n * squircleInset
    let box = CGRect(x: inset, y: inset, width: n - inset * 2, height: n - inset * 2)
    let radius = box.width * cornerRatio
    let squircle = CGPath(roundedRect: box, cornerWidth: radius,
                          cornerHeight: radius, transform: nil)

    // Soft contact shadow, only where there are enough pixels for it to read.
    if px >= 128 {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -n * 0.012),
                      blur: n * 0.035, color: rgb(0, 0, 0, 0.32))
        ctx.addPath(squircle)
        ctx.setFillColor(rgb(0, 0, 0, 1))
        ctx.fillPath()
        ctx.restoreGState()
    }

    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()

    // Indigo → violet, lit from the top-left.
    let space = CGColorSpaceCreateDeviceRGB()
    let gradient = CGGradient(colorsSpace: space,
                              colors: [rgb(64, 106, 245), rgb(120, 47, 214)] as CFArray,
                              locations: [0, 1])!
    ctx.drawLinearGradient(gradient,
                           start: CGPoint(x: box.minX, y: box.maxY),
                           end: CGPoint(x: box.maxX, y: box.minY),
                           options: [])

    // Gloss in the upper-left corner.
    let gloss = CGGradient(colorsSpace: space,
                           colors: [rgb(255, 255, 255, 0.30),
                                    rgb(255, 255, 255, 0)] as CFArray,
                           locations: [0, 1])!
    ctx.drawRadialGradient(gloss,
                           startCenter: CGPoint(x: box.minX + box.width * 0.24,
                                                y: box.maxY - box.height * 0.16),
                           startRadius: 0,
                           endCenter: CGPoint(x: box.minX + box.width * 0.24,
                                              y: box.maxY - box.height * 0.16),
                           endRadius: box.width * 0.72,
                           options: [])

    // ---- zone grid ----------------------------------------------------
    let detailed = px >= 40
    let gridSide = box.width * (detailed ? 0.58 : 0.62)
    let gap = gridSide * 0.11
    let cell = (gridSide - gap) / 2
    let gridOrigin = CGPoint(x: box.midX - gridSide / 2, y: box.midY - gridSide / 2)
    let cellRadius = cell * 0.26

    func cellRect(col: Int, row: Int) -> CGRect {
        CGRect(x: gridOrigin.x + CGFloat(col) * (cell + gap),
               y: gridOrigin.y + CGFloat(row) * (cell + gap),
               width: cell, height: cell)
    }

    // Bottom-left is the lit zone; row 0 is the bottom in this coordinate space.
    let litRect = cellRect(col: 0, row: 0)
    let litCenter = CGPoint(x: litRect.midX, y: litRect.midY)

    // ---- ripples ------------------------------------------------------
    // Kept faint and thin: at full strength they cut straight through the
    // zone outlines and the mark reads as noise rather than a grid.
    // Skipped entirely when small — a single faint ring around an off-centre
    // square just muddies the shape at 16pt.
    if detailed {
        for i in 0..<2 {
            let r = cell * (1.05 + CGFloat(i) * 0.70)
            ctx.setStrokeColor(rgb(255, 255, 255, 0.26 - CGFloat(i) * 0.10))
            ctx.setLineWidth(max(1, n * 0.010))
            ctx.addArc(center: litCenter, radius: r, startAngle: 0,
                       endAngle: .pi * 2, clockwise: false)
            ctx.strokePath()
        }
    }

    // ---- the three unlit zones ----------------------------------------
    // Outlined when there is room for a stroke to survive, solid otherwise:
    // a hairline outline at 16pt collapses into a grey smudge, whereas four
    // filled squares still read as a grid.
    for (col, row) in [(1, 0), (0, 1), (1, 1)] {
        let r = cellRect(col: col, row: row)
        let path = CGPath(roundedRect: r, cornerWidth: cellRadius,
                          cornerHeight: cellRadius, transform: nil)
        ctx.addPath(path)
        if detailed {
            ctx.setStrokeColor(rgb(255, 255, 255, 0.78))
            ctx.setLineWidth(max(1, n * 0.019))
            ctx.strokePath()
        } else {
            ctx.setFillColor(rgb(255, 255, 255, 0.52))
            ctx.fillPath()
        }
    }

    // Lit zone: solid white, with a glow at larger sizes.
    if px >= 128 {
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: n * 0.05, color: rgb(255, 255, 255, 0.75))
        ctx.addPath(CGPath(roundedRect: litRect, cornerWidth: cellRadius,
                           cornerHeight: cellRadius, transform: nil))
        ctx.setFillColor(rgb(255, 255, 255, 1))
        ctx.fillPath()
        ctx.restoreGState()
    } else {
        ctx.addPath(CGPath(roundedRect: litRect, cornerWidth: cellRadius,
                           cornerHeight: cellRadius, transform: nil))
        ctx.setFillColor(rgb(255, 255, 255, 1))
        ctx.fillPath()
    }

    ctx.restoreGState()

    // Hairline edge so the squircle stays defined on light backgrounds.
    if px >= 64 {
        ctx.addPath(squircle)
        ctx.setStrokeColor(rgb(255, 255, 255, 0.16))
        ctx.setLineWidth(max(1, n * 0.004))
        ctx.strokePath()
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for (name, px) in targets {
    let data = drawIcon(px: px)
    let path = outDir + "/" + name
    try! data.write(to: URL(fileURLWithPath: path))
    print("  \(name)  \(px)×\(px)  \(data.count) bytes")
}
print("iconset: \(outDir)")
