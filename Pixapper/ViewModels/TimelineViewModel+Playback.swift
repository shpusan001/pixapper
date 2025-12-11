//
//  TimelineViewModel+Playback.swift
//  Pixapper
//
//  Created by Claude on 2025-12-11.
//

import Foundation

// MARK: - Playback Extension
extension TimelineViewModel {

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

    func startPlayback() {
        stopPlayback()

        let interval = settings.frameDuration
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.advanceFrame()
            }
        }
        if let timer = playbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func advanceFrame() {
        if currentFrameIndex < totalFrames - 1 {
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
        if currentFrameIndex < totalFrames - 1 {
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
            startPlayback()
        }
    }

    func setPlaybackSpeed(_ speed: Double) {
        settings.playbackSpeed = speed
        if isPlaying {
            startPlayback()
        }
    }

    func toggleLoop() {
        settings.isLooping.toggle()
    }

    func toggleOnionSkin() {
        settings.onionSkinEnabled.toggle()
    }
}
