#!/usr/bin/env swift
// Genera AppResources/AppIcon.icns con el logotipo de la app.
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppResources/AppIcon.iconset")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func draw(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()
    guard let ctx = NSGraphicsContext.current?.cgContext else { image.unlockFocus(); return image }

    // Fondo con esquinas de tipo "squircle"
    let inset = s * 0.045
    let rect = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let path = NSBezierPath(roundedRect: rect, xRadius: s * 0.2237, yRadius: s * 0.2237)
    ctx.saveGState()
    path.addClip()
    let colors = [NSColor(calibratedRed: 0.35, green: 0.36, blue: 0.92, alpha: 1).cgColor,
                  NSColor(calibratedRed: 0.20, green: 0.19, blue: 0.60, alpha: 1).cgColor] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(gradient,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: s, y: 0),
                               options: [])
    }
    // Brillo superior suave
    let sheenColors = [NSColor(white: 1, alpha: 0.16).cgColor,
                       NSColor(white: 1, alpha: 0).cgColor] as CFArray
    if let sheen = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: sheenColors, locations: [0, 1]) {
        ctx.drawLinearGradient(sheen,
                               start: CGPoint(x: 0, y: s),
                               end: CGPoint(x: 0, y: s * 0.42),
                               options: [])
    }
    ctx.restoreGState()

    // Marca Markdown: rectángulo redondeado con "M" y flecha
    let markWidth = s * 0.60
    let markHeight = markWidth * 0.62
    let markRect = CGRect(x: (s - markWidth) / 2, y: (s - markHeight) / 2, width: markWidth, height: markHeight)
    let line = max(s * 0.032, 1)
    let mark = NSBezierPath(roundedRect: markRect.insetBy(dx: line / 2, dy: line / 2),
                            xRadius: s * 0.055, yRadius: s * 0.055)
    mark.lineWidth = line
    NSColor.white.setStroke()
    mark.stroke()

    // "M"
    let m = NSBezierPath()
    let pad = markRect.width * 0.14
    let left = markRect.minX + pad
    let bottom = markRect.minY + markRect.height * 0.26
    let top = markRect.maxY - markRect.height * 0.26
    let mWidth = markRect.width * 0.38
    m.move(to: CGPoint(x: left, y: bottom))
    m.line(to: CGPoint(x: left, y: top))
    m.line(to: CGPoint(x: left + mWidth / 2, y: top - (top - bottom) * 0.55))
    m.line(to: CGPoint(x: left + mWidth, y: top))
    m.line(to: CGPoint(x: left + mWidth, y: bottom))
    m.lineWidth = line
    m.lineJoinStyle = .round
    m.lineCapStyle = .round
    NSColor.white.setStroke()
    m.stroke()

    // Flecha hacia abajo
    let arrowX = markRect.maxX - pad - markRect.width * 0.13
    let arrow = NSBezierPath()
    arrow.move(to: CGPoint(x: arrowX, y: top))
    arrow.line(to: CGPoint(x: arrowX, y: bottom + markRect.height * 0.10))
    arrow.lineWidth = line
    arrow.lineCapStyle = .round
    arrow.stroke()

    let head = NSBezierPath()
    let headSize = markRect.width * 0.13
    head.move(to: CGPoint(x: arrowX - headSize, y: bottom + markRect.height * 0.22))
    head.line(to: CGPoint(x: arrowX, y: bottom))
    head.line(to: CGPoint(x: arrowX + headSize, y: bottom + markRect.height * 0.22))
    head.lineWidth = line
    head.lineJoinStyle = .round
    head.lineCapStyle = .round
    head.stroke()

    image.unlockFocus()
    return image
}

func write(_ image: NSImage, to url: URL, pixels: Int) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = NSSize(width: pixels, height: pixels)
    guard let png = rep.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: url)
}

for size in sizes {
    let image = draw(size: size)
    switch size {
    case 16: write(image, to: outDir.appendingPathComponent("icon_16x16.png"), pixels: 16)
    case 32:
        write(image, to: outDir.appendingPathComponent("icon_16x16@2x.png"), pixels: 32)
        write(image, to: outDir.appendingPathComponent("icon_32x32.png"), pixels: 32)
    case 64: write(image, to: outDir.appendingPathComponent("icon_32x32@2x.png"), pixels: 64)
    case 128: write(image, to: outDir.appendingPathComponent("icon_128x128.png"), pixels: 128)
    case 256:
        write(image, to: outDir.appendingPathComponent("icon_128x128@2x.png"), pixels: 256)
        write(image, to: outDir.appendingPathComponent("icon_256x256.png"), pixels: 256)
    case 512:
        write(image, to: outDir.appendingPathComponent("icon_256x256@2x.png"), pixels: 512)
        write(image, to: outDir.appendingPathComponent("icon_512x512.png"), pixels: 512)
    case 1024: write(image, to: outDir.appendingPathComponent("icon_512x512@2x.png"), pixels: 1024)
    default: break
    }
}
print("iconset generado en \(outDir.path)")
