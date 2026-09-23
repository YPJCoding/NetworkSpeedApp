import AppKit

@MainActor
enum MenuBarIconRenderer {
    private static let imageSize = NSSize(width: 61, height: 22)
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium)
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 256
        return cache
    }()

    static func twoLine(upload: String, download: String) -> NSImage {
        let cacheKey = "\(upload)\n\(download)" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image = NSImage(size: imageSize, flipped: false) { rect in
            drawLine(arrow: "↑", value: upload, y: 11, in: rect)
            drawLine(arrow: "↓", value: download, y: 1, in: rect)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "上传 \(upload)，下载 \(download)"
        cache.setObject(image, forKey: cacheKey)
        return image
    }

    private static func drawLine(arrow: String, value: String, y: CGFloat, in rect: NSRect) {
        let arrowStyle = NSMutableParagraphStyle()
        arrowStyle.alignment = .center
        let valueStyle = NSMutableParagraphStyle()
        valueStyle.alignment = .right
        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor
        ]

        let arrowRect = NSRect(x: 0, y: y, width: 7, height: 10)
        let valueRect = NSRect(x: 7, y: y, width: rect.width - 8, height: 10)
        var arrowAttributes = baseAttributes
        arrowAttributes[.paragraphStyle] = arrowStyle
        var valueAttributes = baseAttributes
        valueAttributes[.paragraphStyle] = valueStyle

        (arrow as NSString).draw(in: arrowRect, withAttributes: arrowAttributes)
        (value as NSString).draw(in: valueRect, withAttributes: valueAttributes)
    }
}
