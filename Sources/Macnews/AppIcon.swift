import SwiftUI
import AppKit
import CoreGraphics

public enum AppIcon {
    /// Exact 5 warm vertical stripes from Hotnews `/static/192.png`:
    /// `#FCB13B`, `#F8941E`, `#F25A23`, `#EE2324`, `#C2272D`
    public static let stripeRGBs: [(r: CGFloat, g: CGFloat, b: CGFloat)] = [
        (0xFC / 255.0, 0xB1 / 255.0, 0x3B / 255.0),
        (0xF8 / 255.0, 0x94 / 255.0, 0x1E / 255.0),
        (0xF2 / 255.0, 0x5A / 255.0, 0x23 / 255.0),
        (0xEE / 255.0, 0x23 / 255.0, 0x24 / 255.0),
        (0xC2 / 255.0, 0x27 / 255.0, 0x2D / 255.0)
    ]

    public static func renderPNGData(pixelSize: Int) -> Data? {
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(
                  data: nil,
                  width: pixelSize,
                  height: pixelSize,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else {
            return nil
        }

        draw(in: ctx, pixelSize: pixelSize)

        guard let cgImage = ctx.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: cgImage)
        return rep.representation(using: .png, properties: [:])
    }

    public static func renderNSImage(pointSize: CGFloat = 512) -> NSImage {
        let image = NSImage(size: NSSize(width: pointSize, height: pointSize))
        for scale in [1, 2] {
            let pixelSize = Int(pointSize) * scale
            if let data = renderPNGData(pixelSize: pixelSize),
               let rep = NSBitmapImageRep(data: data) {
                rep.size = NSSize(width: pointSize, height: pointSize)
                image.addRepresentation(rep)
            }
        }
        return image
    }

    public static func loadOrRenderImage() -> NSImage {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        if let url = Bundle.module.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return renderNSImage()
    }

    public static func writeIconset(to directoryURL: URL) throws {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let specs: [(name: String, pixels: Int)] = [
            ("icon_16x16.png", 16),
            ("icon_16x16@2x.png", 32),
            ("icon_32x32.png", 32),
            ("icon_32x32@2x.png", 64),
            ("icon_128x128.png", 128),
            ("icon_128x128@2x.png", 256),
            ("icon_256x256.png", 256),
            ("icon_256x256@2x.png", 512),
            ("icon_512x512.png", 512),
            ("icon_512x512@2x.png", 1024)
        ]
        for spec in specs {
            guard let pngData = renderPNGData(pixelSize: spec.pixels) else {
                throw CocoaError(.fileWriteUnknown)
            }
            try pngData.write(to: directoryURL.appendingPathComponent(spec.name))
        }
    }

    private static func draw(in ctx: CGContext, pixelSize: Int) {
        let size = CGFloat(pixelSize)
        let scale = size / 1024.0

        ctx.saveGState()
        ctx.translateBy(x: 0, y: size)
        ctx.scaleBy(x: scale, y: -scale)

        let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
        let cornerRadius: CGFloat = 185.4
        let squirclePath = Path(
            roundedRect: iconRect,
            cornerRadius: cornerRadius,
            style: .continuous
        ).cgPath

        let baseColor = CGColor(
            srgbRed: stripeRGBs[2].r,
            green: stripeRGBs[2].g,
            blue: stripeRGBs[2].b,
            alpha: 1.0
        )

        // Outer macOS icon drop shadow
        ctx.saveGState()
        ctx.setShadow(
            offset: CGSize(width: 0, height: -10.0 * scale),
            blur: 24.0 * scale,
            color: CGColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.28)
        )
        ctx.addPath(squirclePath)
        ctx.setFillColor(baseColor)
        ctx.fillPath()
        ctx.restoreGState()

        // Clip to squircle and draw 5 vertical stripes
        ctx.saveGState()
        ctx.addPath(squirclePath)
        ctx.clip()

        let stripeCount = CGFloat(stripeRGBs.count)
        let stripeWidth = iconRect.width / stripeCount
        for (index, rgb) in stripeRGBs.enumerated() {
            let x = iconRect.minX + (CGFloat(index) * stripeWidth)
            // Extend width by 1pt on non-final stripes to prevent subpixel seams
            let width = index == stripeRGBs.count - 1 ? stripeWidth : stripeWidth + 1.0
            let rect = CGRect(x: x, y: iconRect.minY, width: width, height: iconRect.height)
            ctx.setFillColor(CGColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1.0))
            ctx.fill(rect)
        }

        ctx.restoreGState()
        ctx.restoreGState()
    }
}
