#!/usr/bin/env swift

import Cocoa
import CoreGraphics

/// Generates BrightSync app icon: black background, thin Studio Display outline with soft glow.

func generateIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }

    // Black background with rounded corners
    let bgRect = CGRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.22
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.setFillColor(CGColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0))
    ctx.addPath(bgPath)
    ctx.fillPath()

    // Scale factors relative to icon size
    let centerX = s / 2
    let centerY = s * 0.52  // Slightly above center

    // Monitor dimensions
    let monW = s * 0.58
    let monH = s * 0.40
    let monRadius = s * 0.03
    let monRect = CGRect(
        x: centerX - monW / 2,
        y: centerY - monH / 2 + s * 0.04,
        width: monW,
        height: monH
    )

    // Stand neck
    let neckW = s * 0.06
    let neckH = s * 0.10
    let neckRect = CGRect(
        x: centerX - neckW / 2,
        y: monRect.minY - neckH + s * 0.005,
        width: neckW,
        height: neckH
    )

    // Stand base (thin oval/rectangle)
    let baseW = s * 0.22
    let baseH = s * 0.02
    let baseRect = CGRect(
        x: centerX - baseW / 2,
        y: neckRect.minY - baseH + s * 0.005,
        width: baseW,
        height: baseH
    )

    let strokeWidth = s * 0.015
    let glowColor = CGColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 1.0)  // Soft blue-white
    let outlineColor = CGColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 0.95)

    // Draw glow layers (multiple passes for soft glow)
    for i in stride(from: 5, through: 1, by: -1) {
        let glowRadius = CGFloat(i) * s * 0.012
        let alpha = 0.08 / CGFloat(i)
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: glowRadius, color: CGColor(red: 0.5, green: 0.7, blue: 1.0, alpha: alpha))

        // Monitor glow
        let monPath = CGPath(roundedRect: monRect, cornerWidth: monRadius, cornerHeight: monRadius, transform: nil)
        ctx.setStrokeColor(glowColor)
        ctx.setLineWidth(strokeWidth * 1.5)
        ctx.addPath(monPath)
        ctx.strokePath()

        ctx.restoreGState()
    }

    // Draw the monitor outline
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.04, color: glowColor)
    let monPath = CGPath(roundedRect: monRect, cornerWidth: monRadius, cornerHeight: monRadius, transform: nil)
    ctx.setStrokeColor(outlineColor)
    ctx.setLineWidth(strokeWidth)
    ctx.addPath(monPath)
    ctx.strokePath()
    ctx.restoreGState()

    // Draw the stand neck with glow
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.025, color: glowColor)
    ctx.setStrokeColor(outlineColor)
    ctx.setLineWidth(strokeWidth * 0.8)
    ctx.addRect(neckRect)
    ctx.strokePath()
    ctx.restoreGState()

    // Draw the stand base with glow
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.025, color: glowColor)
    let basePath = CGPath(roundedRect: baseRect, cornerWidth: baseH / 2, cornerHeight: baseH / 2, transform: nil)
    ctx.setStrokeColor(outlineColor)
    ctx.setLineWidth(strokeWidth * 0.8)
    ctx.addPath(basePath)
    ctx.strokePath()
    ctx.restoreGState()

    // Screen bezel line (thin inner border at the bottom of the screen, like Studio Display chin)
    let chinHeight = s * 0.03
    let chinY = monRect.minY + chinHeight
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.01, color: glowColor)
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 0.4))
    ctx.setLineWidth(strokeWidth * 0.4)
    ctx.move(to: CGPoint(x: monRect.minX + monRadius, y: chinY))
    ctx.addLine(to: CGPoint(x: monRect.maxX - monRadius, y: chinY))
    ctx.strokePath()
    ctx.restoreGState()

    // Subtle screen content: a small brightness sun icon in the center of the screen
    let sunCenter = CGPoint(x: centerX, y: monRect.midY + s * 0.02)
    let sunRadius = s * 0.06
    let rayLength = s * 0.03

    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: s * 0.03, color: CGColor(red: 0.6, green: 0.75, blue: 1.0, alpha: 0.6))

    // Sun circle
    ctx.setStrokeColor(CGColor(red: 0.85, green: 0.9, blue: 1.0, alpha: 0.5))
    ctx.setLineWidth(strokeWidth * 0.6)
    ctx.addArc(center: sunCenter, radius: sunRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()

    // Sun rays
    ctx.setLineWidth(strokeWidth * 0.5)
    for angle in stride(from: 0.0, to: Double.pi * 2, by: Double.pi / 4) {
        let innerR = sunRadius + s * 0.015
        let outerR = sunRadius + rayLength
        let startPt = CGPoint(
            x: sunCenter.x + CGFloat(cos(angle)) * innerR,
            y: sunCenter.y + CGFloat(sin(angle)) * outerR
        )
        let endPt = CGPoint(
            x: sunCenter.x + CGFloat(cos(angle)) * outerR,
            y: sunCenter.y + CGFloat(sin(angle)) * (outerR + s * 0.008)
        )
        ctx.move(to: startPt)
        ctx.addLine(to: endPt)
    }
    ctx.strokePath()

    ctx.restoreGState()

    image.unlockFocus()
    return image
}

func savePNG(_ image: NSImage, to path: String, size: Int) {
    let targetSize = NSSize(width: size, height: size)
    let newImage = NSImage(size: targetSize)
    newImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: targetSize),
               from: NSRect(origin: .zero, size: image.size),
               operation: .copy, fraction: 1.0)
    newImage.unlockFocus()

    guard let tiffData = newImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for size \(size)")
        return
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Saved \(size)x\(size) icon to \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Generate at high resolution then scale down
let masterImage = generateIcon(size: 1024)

let assetDir = "BrightSync/Resources/Assets.xcassets/AppIcon.appiconset"

// macOS icon sizes
let sizes: [(Int, String)] = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

for (size, filename) in sizes {
    savePNG(masterImage, to: "\(assetDir)/\(filename)", size: size)
}

print("Done! All icon sizes generated.")
