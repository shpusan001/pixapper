//
//  ExportManager.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

enum ExportFormat {
    case singleImage
    case spriteSheet(layout: SpriteSheetLayout, padding: Int)
    case pngSequence
}

enum SpriteSheetLayout: String, CaseIterable, Identifiable {
    case horizontal = "Horizontal"
    case vertical = "Vertical"
    case grid = "Grid"

    var id: String { rawValue }
}

class ExportManager {

    // MARK: - Single Image Export

    static func exportSingleImage(frame: Frame, width: Int, height: Int) -> NSImage? {
        return renderFrameToImage(frame: frame, width: width, height: height)
    }

    // MARK: - Sprite Sheet Export

    static func exportSpriteSheet(frames: [Frame], width: Int, height: Int, layout: SpriteSheetLayout, padding: Int) -> NSImage? {
        guard !frames.isEmpty else { return nil }

        let frameCount = frames.count
        let (columns, rows) = calculateSpriteSheetDimensions(frameCount: frameCount, layout: layout)

        let totalWidth = columns * width + (columns - 1) * padding
        let totalHeight = rows * height + (rows - 1) * padding

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight))

        image.lockFocus()

        for (index, frame) in frames.enumerated() {
            let (col, row) = getSpriteSheetPosition(index: index, columns: columns, layout: layout)
            let x = col * (width + padding)
            let y = row * (height + padding)

            if let frameImage = renderFrameToImage(frame: frame, width: width, height: height) {
                frameImage.draw(at: NSPoint(x: x, y: totalHeight - y - height), from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        }

        image.unlockFocus()

        return image
    }

    private static func calculateSpriteSheetDimensions(frameCount: Int, layout: SpriteSheetLayout) -> (columns: Int, rows: Int) {
        switch layout {
        case .horizontal:
            return (frameCount, 1)
        case .vertical:
            return (1, frameCount)
        case .grid:
            let columns = Int(ceil(sqrt(Double(frameCount))))
            let rows = Int(ceil(Double(frameCount) / Double(columns)))
            return (columns, rows)
        }
    }

    private static func getSpriteSheetPosition(index: Int, columns: Int, layout: SpriteSheetLayout) -> (col: Int, row: Int) {
        switch layout {
        case .horizontal:
            return (index, 0)
        case .vertical:
            return (0, index)
        case .grid:
            return (index % columns, index / columns)
        }
    }

    // MARK: - PNG Sequence Export

    static func exportPNGSequence(frames: [Frame], width: Int, height: Int, directoryURL: URL, baseName: String) -> Bool {
        guard !frames.isEmpty else { return false }

        for (index, frame) in frames.enumerated() {
            guard let image = renderFrameToImage(frame: frame, width: width, height: height) else {
                return false
            }

            let fileName = String(format: "%@_%03d.png", baseName, index + 1)
            let fileURL = directoryURL.appendingPathComponent(fileName)

            guard savePNG(image: image, to: fileURL) else {
                return false
            }
        }

        return true
    }

    // MARK: - Helper Methods

    private static func renderFrameToImage(frame: Frame, width: Int, height: Int) -> NSImage? {
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()

        // Render each visible layer
        for layer in frame.layers where layer.isVisible {
            for y in 0..<layer.pixels.count {
                for x in 0..<layer.pixels[y].count {
                    if let color = layer.pixels[y][x] {
                        let nsColor = NSColor(color.opacity(layer.opacity))
                        nsColor.setFill()
                        let rect = NSRect(x: x, y: height - y - 1, width: 1, height: 1)
                        NSBezierPath(rect: rect).fill()
                    }
                }
            }
        }

        image.unlockFocus()

        return image
    }

    private static func savePNG(image: NSImage, to url: URL) -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return false
        }

        do {
            try pngData.write(to: url)
            return true
        } catch {
            print("Failed to save PNG: \(error)")
            return false
        }
    }

    static func savePNG(image: NSImage, showingSavePanel: Bool = true) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.png]
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "export.png"

        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                _ = savePNG(image: image, to: url)
            }
        }
    }

    static func chooseSaveLocation(defaultName: String, completion: @escaping (URL?) -> Void) {
        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = defaultName

        savePanel.begin { response in
            if response == .OK {
                completion(savePanel.url)
            } else {
                completion(nil)
            }
        }
    }

    static func chooseDirectory(completion: @escaping (URL?) -> Void) {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.canCreateDirectories = true

        openPanel.begin { response in
            if response == .OK {
                completion(openPanel.url)
            } else {
                completion(nil)
            }
        }
    }
}
