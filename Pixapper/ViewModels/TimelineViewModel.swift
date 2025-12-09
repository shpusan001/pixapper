//
//  TimelineViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

class TimelineViewModel: ObservableObject {
    @Published var frames: [Frame]
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var settings = AnimationSettings()

    private var playbackTimer: Timer?
    private let canvasWidth: Int
    private let canvasHeight: Int

    var layerViewModel: LayerViewModel

    init(width: Int, height: Int, layerViewModel: LayerViewModel) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.layerViewModel = layerViewModel

        // Initialize with one frame containing the current layers
        self.frames = [Frame(layers: layerViewModel.layers)]

        // Sync layer changes to current frame
        layerViewModel.$layers
            .sink { [weak self] layers in
                guard let self = self else { return }
                if self.currentFrameIndex < self.frames.count {
                    self.frames[self.currentFrameIndex].layers = layers
                }
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Frame Management

    func addFrame() {
        let newFrame = Frame(width: canvasWidth, height: canvasHeight)
        frames.append(newFrame)
        currentFrameIndex = frames.count - 1
        loadFrame(at: currentFrameIndex)
    }

    func deleteFrame(at index: Int) {
        guard frames.count > 1 && index < frames.count else { return }
        frames.remove(at: index)
        if currentFrameIndex >= frames.count {
            currentFrameIndex = frames.count - 1
        }
        loadFrame(at: currentFrameIndex)
    }

    func duplicateFrame(at index: Int) {
        guard index < frames.count else { return }
        let duplicatedFrame = Frame(layers: frames[index].layers.map { layer in
            var newLayer = layer
            return newLayer
        })
        frames.insert(duplicatedFrame, at: index + 1)
        currentFrameIndex = index + 1
        loadFrame(at: currentFrameIndex)
    }

    func selectFrame(at index: Int) {
        guard index < frames.count else { return }
        currentFrameIndex = index
        loadFrame(at: index)
    }

    private func loadFrame(at index: Int) {
        guard index < frames.count else { return }
        layerViewModel.layers = frames[index].layers
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    func play() {
        isPlaying = true
        startPlayback()
    }

    func pause() {
        isPlaying = false
        stopPlayback()
    }

    private func startPlayback() {
        stopPlayback()

        let interval = settings.frameDuration
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.advanceFrame()
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func advanceFrame() {
        if currentFrameIndex < frames.count - 1 {
            currentFrameIndex += 1
        } else if settings.isLooping {
            currentFrameIndex = 0
        } else {
            pause()
            return
        }
        loadFrame(at: currentFrameIndex)
    }

    func nextFrame() {
        if currentFrameIndex < frames.count - 1 {
            currentFrameIndex += 1
            loadFrame(at: currentFrameIndex)
        }
    }

    func previousFrame() {
        if currentFrameIndex > 0 {
            currentFrameIndex -= 1
            loadFrame(at: currentFrameIndex)
        }
    }

    // MARK: - Settings

    func setFPS(_ fps: Int) {
        settings.fps = fps
        if isPlaying {
            startPlayback() // Restart with new timing
        }
    }

    func setPlaybackSpeed(_ speed: Double) {
        settings.playbackSpeed = speed
        if isPlaying {
            startPlayback() // Restart with new timing
        }
    }

    func toggleLoop() {
        settings.isLooping.toggle()
    }

    func toggleOnionSkin() {
        settings.onionSkinEnabled.toggle()
    }

    // MARK: - Onion Skin Helpers

    func getOnionSkinFrames() -> [(frame: Frame, tint: Color, opacity: Double)] {
        var result: [(frame: Frame, tint: Color, opacity: Double)] = []

        if !settings.onionSkinEnabled {
            return result
        }

        // Previous frames (red tint)
        for i in 1...settings.onionSkinPrevFrames {
            let frameIndex = currentFrameIndex - i
            if frameIndex >= 0 && frameIndex < frames.count {
                let opacity = settings.onionSkinOpacity / Double(i)
                result.append((frames[frameIndex], .red, opacity))
            }
        }

        // Next frames (blue tint)
        for i in 1...settings.onionSkinNextFrames {
            let frameIndex = currentFrameIndex + i
            if frameIndex >= 0 && frameIndex < frames.count {
                let opacity = settings.onionSkinOpacity / Double(i)
                result.append((frames[frameIndex], .blue, opacity))
            }
        }

        return result
    }

    deinit {
        stopPlayback()
    }
}
