import AppKit
import Foundation

let arguments = CommandLine.arguments
precondition(arguments.count == 3, "用法：generate-icon.swift <尺寸> <输出路径>")
let size = Int(arguments[1])!
let output = arguments[2]
let canvas = NSSize(width: size, height: size)
let image = NSImage(size: canvas)
image.lockFocus()

let rect = NSRect(origin: .zero, size: canvas).insetBy(dx: CGFloat(size) * 0.06, dy: CGFloat(size) * 0.06)
let background = NSBezierPath(roundedRect: rect, xRadius: CGFloat(size) * 0.22, yRadius: CGFloat(size) * 0.22)
NSColor(calibratedRed: 0.08, green: 0.45, blue: 0.95, alpha: 1).setFill()
background.fill()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: CGFloat(size) * 0.48, weight: .bold),
    .foregroundColor: NSColor.white,
    .paragraphStyle: paragraph
]
let text = "↕" as NSString
let textRect = NSRect(x: 0, y: CGFloat(size) * 0.16, width: CGFloat(size), height: CGFloat(size) * 0.62)
text.draw(in: textRect, withAttributes: attributes)
image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: output))
