//
//  ExportViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/18/25.
//

import SwiftUI
import Combine

class ExportViewModel: ObservableObject {
    // MARK: - Properties

    @Published var selectedFormat: ExportFormat = .singleImage
    @Published var previewImage: NSImage?
    @Published var isGeneratingPreview = false
    @Published var showingErrorAlert = false
    @Published var errorMessage = ""
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0

    private var exportTask: Task<Void, Never>?

    // Single Image - 설정 없음

    // Sprite Sheet 설정
    @Published var spriteSheetLayout: SpriteSheetLayout = .horizontal
    @Published var spriteSheetPadding: Int = 0
    @Published var spriteSheetGridColumns: Int = 4
    @Published var spriteSheetGridRows: Int = 4

    // PNG Sequence 설정
    @Published var sequenceBaseName: String = "frame"

    // GIF 설정
    @Published var gifFPS: Int = 12
    @Published var gifLoopCount: Int = 0 // 0 = 무한
    @Published var gifRenderMode: GIFRenderMode = .pixelPerfect

    // MP4 설정
    @Published var mp4FPS: Int = 12
    @Published var mp4Quality: MP4Quality = .lossless
    @Published var mp4RenderMode: MP4RenderMode = .pixelPerfect

    // Dependencies
    let timelineViewModel: TimelineViewModel
    let canvasWidth: Int
    let canvasHeight: Int

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(timelineViewModel: TimelineViewModel, canvasWidth: Int, canvasHeight: Int) {
        self.timelineViewModel = timelineViewModel
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight

        setupPreviewUpdates()
    }

    // MARK: - Preview Updates

    private func setupPreviewUpdates() {
        // 포맷 변경 시 미리보기 자동 업데이트
        Publishers.CombineLatest3(
            $selectedFormat,
            $spriteSheetLayout,
            $spriteSheetPadding
        )
        .debounce(for: 0.3, scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.generatePreview()
        }
        .store(in: &cancellables)
    }

    func generatePreview() {
        isGeneratingPreview = true

        Task { @MainActor in
            let preview = await generatePreviewImage()
            self.previewImage = preview
            self.isGeneratingPreview = false
        }
    }

    private func generatePreviewImage() async -> NSImage? {
        let resolvedFrames = timelineViewModel.getResolvedFrames()
        let layers = timelineViewModel.layerViewModel.layers

        switch selectedFormat {
        case .singleImage:
            let currentFrame = resolvedFrames[timelineViewModel.currentFrameIndex]
            return ExportManager.exportSingleImage(
                frame: currentFrame,
                layers: layers,
                width: canvasWidth,
                height: canvasHeight
            )

        case .spriteSheet:
            return ExportManager.exportSpriteSheet(
                frames: resolvedFrames,
                layers: layers,
                width: canvasWidth,
                height: canvasHeight,
                layout: spriteSheetLayout,
                padding: spriteSheetPadding,
                gridColumns: spriteSheetGridColumns,
                gridRows: spriteSheetGridRows
            )

        case .pngSequence:
            // PNG Sequence는 첫 프레임만 미리보기
            let firstFrame = resolvedFrames.first ?? resolvedFrames[timelineViewModel.currentFrameIndex]
            return ExportManager.exportSingleImage(
                frame: firstFrame,
                layers: layers,
                width: canvasWidth,
                height: canvasHeight
            )

        case .gif:
            // GIF 미리보기는 생성 비용이 높아서 제공하지 않음
            return nil

        case .mp4:
            // MP4 미리보기는 인코딩 비용이 높아서 제공하지 않음
            return nil
        }
    }

    // MARK: - Export

    func performExport(completion: @escaping () -> Void) {
        // Cancel any existing task
        cancelExport()

        isExporting = true
        exportProgress = 0.0

        let resolvedFrames = timelineViewModel.getResolvedFrames()
        let layers = timelineViewModel.layerViewModel.layers

        // Run export in background
        exportTask = Task { @MainActor in
            // Check for cancellation
            guard !Task.isCancelled else {
                self.isExporting = false
                self.exportProgress = 0.0
                completion()
                return
            }

            switch selectedFormat {
            case .singleImage:
                await exportSingleImage(frames: resolvedFrames, layers: layers)

            case .spriteSheet:
                await exportSpriteSheet(frames: resolvedFrames, layers: layers)

            case .pngSequence:
                await exportPNGSequence(frames: resolvedFrames, layers: layers)

            case .gif:
                await exportGIF(frames: resolvedFrames, layers: layers)

            case .mp4:
                await exportMP4(frames: resolvedFrames, layers: layers)
            }

            // Reset state and close
            self.isExporting = false
            self.exportProgress = 0.0

            // Only call completion if not cancelled
            if !Task.isCancelled {
                completion()
            }
        }
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        isExporting = false
        exportProgress = 0.0
    }

    @MainActor
    private func exportSingleImage(frames: [Frame], layers: [Layer]) async {
        guard !Task.isCancelled else { return }

        let currentFrame = frames[timelineViewModel.currentFrameIndex]

        exportProgress = 0.5

        guard !Task.isCancelled else { return }

        if let image = ExportManager.exportSingleImage(
            frame: currentFrame,
            layers: layers,
            width: canvasWidth,
            height: canvasHeight
        ) {
            exportProgress = 0.8

            guard !Task.isCancelled else { return }

            // savePNG shows a dialog
            ExportManager.savePNG(image: image)
        }

        exportProgress = 1.0
    }

    @MainActor
    private func exportSpriteSheet(frames: [Frame], layers: [Layer]) async {
        guard !Task.isCancelled else { return }

        exportProgress = 0.3

        guard !Task.isCancelled else { return }

        if let image = ExportManager.exportSpriteSheet(
            frames: frames,
            layers: layers,
            width: canvasWidth,
            height: canvasHeight,
            layout: spriteSheetLayout,
            padding: spriteSheetPadding,
            gridColumns: spriteSheetGridColumns,
            gridRows: spriteSheetGridRows
        ) {
            exportProgress = 0.8

            guard !Task.isCancelled else { return }

            ExportManager.savePNG(image: image)
        }

        exportProgress = 1.0
    }

    @MainActor
    private func exportPNGSequence(frames: [Frame], layers: [Layer]) async {
        await withCheckedContinuation { continuation in
            ExportManager.chooseDirectory { [weak self] url in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                guard let directoryURL = url else {
                    continuation.resume()
                    return
                }

                let result = ExportManager.exportPNGSequence(
                    frames: frames,
                    layers: layers,
                    width: self.canvasWidth,
                    height: self.canvasHeight,
                    directoryURL: directoryURL,
                    baseName: self.sequenceBaseName
                )

                Task { @MainActor in
                    self.exportProgress = 1.0

                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showingErrorAlert = true
                    }

                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func exportGIF(frames: [Frame], layers: [Layer]) async {
        await withCheckedContinuation { continuation in
            ExportManager.chooseSaveLocation(defaultName: "animation.gif") { [weak self] url in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                guard let saveURL = url else {
                    continuation.resume()
                    return
                }

                Task { @MainActor in
                    self.exportProgress = 0.1

                    let result = ExportManager.exportGIF(
                        frames: frames,
                        layers: layers,
                        width: self.canvasWidth,
                        height: self.canvasHeight,
                        fps: self.gifFPS,
                        loopCount: self.gifLoopCount,
                        renderMode: self.gifRenderMode,
                        to: saveURL
                    )

                    self.exportProgress = 1.0

                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showingErrorAlert = true
                    }

                    continuation.resume()
                }
            }
        }
    }

    @MainActor
    private func exportMP4(frames: [Frame], layers: [Layer]) async {
        await withCheckedContinuation { continuation in
            ExportManager.chooseSaveLocation(defaultName: "animation.mp4") { [weak self] url in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                guard let saveURL = url else {
                    continuation.resume()
                    return
                }

                Task { @MainActor in
                    self.exportProgress = 0.1

                    let result = ExportManager.exportMP4(
                        frames: frames,
                        layers: layers,
                        width: self.canvasWidth,
                        height: self.canvasHeight,
                        fps: self.mp4FPS,
                        quality: self.mp4Quality,
                        renderMode: self.mp4RenderMode,
                        to: saveURL
                    )

                    self.exportProgress = 1.0

                    switch result {
                    case .success:
                        break
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showingErrorAlert = true
                    }

                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Supporting Types

enum ExportFormat: String, CaseIterable, Identifiable {
    case singleImage = "Single Image"
    case spriteSheet = "Sprite Sheet"
    case pngSequence = "PNG Sequence"
    case gif = "GIF"
    case mp4 = "MP4"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .singleImage: return "photo"
        case .spriteSheet: return "square.grid.2x2"
        case .pngSequence: return "photo.stack"
        case .gif: return "film"
        case .mp4: return "video"
        }
    }
}

enum MP4Quality: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case lossless = "Lossless"

    var id: String { rawValue }

    var bitrate: Int {
        switch self {
        case .low: return 2_000_000      // 2 Mbps
        case .medium: return 8_000_000   // 8 Mbps
        case .high: return 20_000_000    // 20 Mbps
        case .lossless: return 50_000_000 // 50 Mbps for near-lossless
        }
    }
}

enum MP4RenderMode: String, CaseIterable, Identifiable {
    case pixelPerfect = "Pixel Perfect"
    case smooth = "Smooth"

    var id: String { rawValue }
}

enum GIFRenderMode: String, CaseIterable, Identifiable {
    case pixelPerfect = "Pixel Perfect"
    case smooth = "Smooth"

    var id: String { rawValue }
}
