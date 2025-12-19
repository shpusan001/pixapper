//
//  ExportManager.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers
import ImageIO
import AVFoundation
import CoreVideo

/// Export 작업 중 발생할 수 있는 에러
enum ExportError: LocalizedError {
    case invalidImageData
    case saveFailed(Error)
    case noFramesToExport
    case gifEncodingFailed
    case videoEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "이미지 데이터를 생성할 수 없습니다."
        case .saveFailed(let error):
            return "저장 실패: \(error.localizedDescription)"
        case .noFramesToExport:
            return "내보낼 프레임이 없습니다."
        case .gifEncodingFailed:
            return "GIF 인코딩에 실패했습니다."
        case .videoEncodingFailed:
            return "비디오 인코딩에 실패했습니다."
        }
    }
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

    static func exportSpriteSheet(frames: [Frame], layers: [Layer], width: Int, height: Int, layout: SpriteSheetLayout, padding: Int, gridColumns: Int, gridRows: Int) -> NSImage? {
        guard !frames.isEmpty else { return nil }

        let frameCount = frames.count
        let (columns, rows) = calculateSpriteSheetDimensions(frameCount: frameCount, layout: layout, gridColumns: gridColumns, gridRows: gridRows)

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

    private static func calculateSpriteSheetDimensions(frameCount: Int, layout: SpriteSheetLayout, gridColumns: Int, gridRows: Int) -> (columns: Int, rows: Int) {
        switch layout {
        case .horizontal:
            return (frameCount, 1)
        case .vertical:
            return (1, frameCount)
        case .grid:
            return (gridColumns, gridRows)
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

    /// Render frame to CGImage with pixel-perfect quality
    private static func renderFrameToCGImage(frame: Frame, layers: [Layer], width: Int, height: Int, pixelPerfect: Bool = true) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        // Critical: Set interpolation to none for pixel-perfect rendering
        context.interpolationQuality = pixelPerfect ? .none : .high

        // Fill with transparent background
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        // Render each visible layer (bottom to top for proper layering)
        for layer in layers where layer.isVisible {
            guard let cell = frame.cell(for: layer.id) else { continue }

            for y in 0..<cell.pixels.count {
                for x in 0..<cell.pixels[y].count {
                    if let color = cell.pixels[y][x] {
                        // Apply layer opacity
                        let finalColor = color.opacity(layer.opacity)

                        // Convert SwiftUI Color to CGColor
                        let nsColor = NSColor(finalColor)
                        context.setFillColor(nsColor.cgColor)

                        // Draw single pixel (flip Y coordinate)
                        let rect = CGRect(x: x, y: height - y - 1, width: 1, height: 1)
                        context.fill(rect)
                    }
                }
            }
        }

        return context.makeImage()
    }

    /// Render frame to NSImage (wrapper for compatibility)
    private static func renderFrameToImage(frame: Frame, layers: [Layer], width: Int, height: Int) -> NSImage? {
        guard let cgImage = renderFrameToCGImage(frame: frame, layers: layers, width: width, height: height, pixelPerfect: true) else {
            return nil
        }

        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        return nsImage
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

    // MARK: - GIF Export

    static func exportGIF(frames: [Frame], layers: [Layer], width: Int, height: Int, fps: Int, loopCount: Int, renderMode: GIFRenderMode, to url: URL) -> Result<Void, ExportError> {
        guard !frames.isEmpty else {
            return .failure(.noFramesToExport)
        }

        // Create GIF destination
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.gif.identifier as CFString, frames.count, nil) else {
            return .failure(.gifEncodingFailed)
        }

        // GIF properties: loop count
        let gifProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFLoopCount as String: loopCount
            ]
        ]
        CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)

        // Frame delay (in seconds)
        let frameDelay = 1.0 / Double(fps)

        // Frame properties
        let frameProperties: [String: Any] = [
            kCGImagePropertyGIFDictionary as String: [
                kCGImagePropertyGIFDelayTime as String: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime as String: frameDelay
            ]
        ]

        // Determine pixel perfect mode
        let pixelPerfect = (renderMode == .pixelPerfect)

        // Add each frame to the GIF
        for frame in frames {
            guard let cgImage = renderFrameToCGImage(frame: frame, layers: layers, width: width, height: height, pixelPerfect: pixelPerfect) else {
                return .failure(.invalidImageData)
            }

            CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
        }

        // Finalize the GIF
        guard CGImageDestinationFinalize(destination) else {
            return .failure(.gifEncodingFailed)
        }

        return .success(())
    }

    // MARK: - MP4 Export

    static func exportMP4(frames: [Frame], layers: [Layer], width: Int, height: Int, fps: Int, quality: MP4Quality, renderMode: MP4RenderMode, to url: URL) -> Result<Void, ExportError> {
        guard !frames.isEmpty else {
            return .failure(.noFramesToExport)
        }

        // Remove existing file if it exists
        try? FileManager.default.removeItem(at: url)

        // Create AVAssetWriter
        guard let videoWriter = try? AVAssetWriter(outputURL: url, fileType: .mp4) else {
            return .failure(.videoEncodingFailed)
        }

        // Video settings - optimized for pixel art
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: quality.bitrate,
                AVVideoMaxKeyFrameIntervalKey: fps, // Keyframe every second
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoAllowFrameReorderingKey: false // Better for pixel art
            ]
        ]

        // Create video input
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false

        // Pixel buffer attributes - use BGRA for better H.264 compatibility
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard videoWriter.canAdd(videoInput) else {
            return .failure(.videoEncodingFailed)
        }

        videoWriter.add(videoInput)

        // Start writing
        guard videoWriter.startWriting() else {
            return .failure(.videoEncodingFailed)
        }

        videoWriter.startSession(atSourceTime: .zero)

        // Frame duration
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))

        // Dispatch semaphore for synchronization
        let semaphore = DispatchSemaphore(value: 0)
        var exportError: ExportError?

        // Add frames
        var frameIndex = 0
        videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "com.pixapper.videoExport")) {
            while videoInput.isReadyForMoreMediaData && frameIndex < frames.count {
                let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
                let frame = frames[frameIndex]

                // Render frame to CGImage directly for pixel-perfect quality
                let pixelPerfect = (renderMode == .pixelPerfect)
                guard let cgImage = renderFrameToCGImage(frame: frame, layers: layers, width: width, height: height, pixelPerfect: pixelPerfect),
                      let pixelBuffer = createPixelBuffer(from: cgImage, width: width, height: height, pixelPerfect: pixelPerfect) else {
                    exportError = .invalidImageData
                    semaphore.signal()
                    return
                }

                // Append pixel buffer
                guard pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                    exportError = .videoEncodingFailed
                    semaphore.signal()
                    return
                }

                frameIndex += 1
            }

            if frameIndex >= frames.count {
                videoInput.markAsFinished()
                videoWriter.finishWriting {
                    semaphore.signal()
                }
            }
        }

        // Wait for completion
        semaphore.wait()

        if let error = exportError {
            return .failure(error)
        }

        if videoWriter.status == .failed {
            return .failure(.videoEncodingFailed)
        }

        return .success(())
    }

    // MARK: - Helper: Create CVPixelBuffer from CGImage

    private static func createPixelBuffer(from cgImage: CGImage, width: Int, height: Int, pixelPerfect: Bool) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA, // Changed to BGRA for better H.264 compatibility
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // Use premultipliedFirst for BGRA format
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let context = CGContext(
            data: baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Critical: Set interpolation quality for pixel-perfect rendering
        context.interpolationQuality = pixelPerfect ? .none : .high

        // Disable antialiasing for pixel-perfect rendering
        if pixelPerfect {
            context.setShouldAntialias(false)
            context.setAllowsAntialiasing(false)
        }

        // Draw CGImage into context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}
