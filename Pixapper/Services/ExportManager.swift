//
//  ExportManager.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Export 작업 중 발생할 수 있는 에러
enum ExportError: LocalizedError {
    case invalidImageData
    case saveFailed(Error)
    case noFramesToExport

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "이미지 데이터를 생성할 수 없습니다."
        case .saveFailed(let error):
            return "저장 실패: \(error.localizedDescription)"
        case .noFramesToExport:
            return "내보낼 프레임이 없습니다."
        }
    }
}

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

    static func exportSingleImage(frame: Frame, layers: [Layer], width: Int, height: Int) -> NSImage? {
        return renderFrameToImage(frame: frame, layers: layers, width: width, height: height)
    }

    // MARK: - Sprite Sheet Export

    static func exportSpriteSheet(frames: [Frame], layers: [Layer], width: Int, height: Int, layout: SpriteSheetLayout, padding: Int) -> NSImage? {
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

            if let frameImage = renderFrameToImage(frame: frame, layers: layers, width: width, height: height) {
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

    static func exportPNGSequence(frames: [Frame], layers: [Layer], width: Int, height: Int, directoryURL: URL, baseName: String) -> Result<Void, ExportError> {
        guard !frames.isEmpty else {
            return .failure(.noFramesToExport)
        }

        for (index, frame) in frames.enumerated() {
            guard let image = renderFrameToImage(frame: frame, layers: layers, width: width, height: height) else {
                return .failure(.invalidImageData)
            }

            let fileName = String(format: "%@_%03d.png", baseName, index + 1)
            let fileURL = directoryURL.appendingPathComponent(fileName)

            let result = savePNG(image: image, to: fileURL)
            if case .failure(let error) = result {
                return .failure(error)
            }
        }

        return .success(())
    }

    // MARK: - Helper Methods

    private static func renderFrameToImage(frame: Frame, layers: [Layer], width: Int, height: Int) -> NSImage? {
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()

        // Render each visible layer
        for layer in layers where layer.isVisible {
            // Find the corresponding cell for this layer
            guard let cell = frame.cell(for: layer.id) else { continue }

            for y in 0..<cell.pixels.count {
                for x in 0..<cell.pixels[y].count {
                    if let color = cell.pixels[y][x] {
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

    private static func savePNG(image: NSImage, to url: URL) -> Result<Void, ExportError> {
        guard let tiffData = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            return .failure(.invalidImageData)
        }

        do {
            try pngData.write(to: url)
            return .success(())
        } catch {
            return .failure(.saveFailed(error))
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
