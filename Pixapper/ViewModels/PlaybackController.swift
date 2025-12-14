//
//  PlaybackController.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI
import Combine

/// PlaybackController의 Delegate 프로토콜
/// - Note: TimelineViewModel이 이 프로토콜을 구현하여 프레임 관리를 담당
@MainActor
protocol PlaybackControllerDelegate: AnyObject {
    var currentFrameIndex: Int { get set }
    var totalFrames: Int { get }
    func loadFrame(at index: Int)
}

/// 애니메이션 플레이백 전용 컨트롤러
/// - Note: TimelineViewModel에서 분리하여 단일 책임 원칙 준수
@MainActor
class PlaybackController: ObservableObject {
    // MARK: - Published State

    @Published var isPlaying: Bool = false
    @Published var settings = AnimationSettings()

    // MARK: - Dependencies

    weak var delegate: PlaybackControllerDelegate?

    // MARK: - Private State

    private var playbackTimer: Timer?

    // MARK: - Playback Control

    /// 애니메이션 재생 시작
    func play() {
        guard !isPlaying else { return }
        isPlaying = true
        startPlayback()
    }

    /// 애니메이션 일시정지
    func pause() {
        isPlaying = false
        stopPlayback()
    }

    /// 재생/일시정지 토글
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    // MARK: - Frame Navigation

    /// 다음 프레임으로 이동
    func nextFrame() {
        guard let delegate = delegate else { return }
        if delegate.currentFrameIndex < delegate.totalFrames - 1 {
            delegate.currentFrameIndex += 1
            delegate.loadFrame(at: delegate.currentFrameIndex)
        }
    }

    /// 이전 프레임으로 이동
    func previousFrame() {
        guard let delegate = delegate else { return }
        if delegate.currentFrameIndex > 0 {
            delegate.currentFrameIndex -= 1
            delegate.loadFrame(at: delegate.currentFrameIndex)
        }
    }

    /// 첫 프레임으로 이동
    func goToFirstFrame() {
        guard let delegate = delegate else { return }
        delegate.currentFrameIndex = 0
        delegate.loadFrame(at: 0)
    }

    /// 마지막 프레임으로 이동
    func goToLastFrame() {
        guard let delegate = delegate else { return }
        let lastIndex = delegate.totalFrames - 1
        delegate.currentFrameIndex = lastIndex
        delegate.loadFrame(at: lastIndex)
    }

    // MARK: - Private Methods

    /// 타이머 기반 플레이백 시작
    private func startPlayback() {
        stopPlayback()

        let interval = 1.0 / settings.effectiveFPS
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.advanceFrame()
            }
        }
        if let timer = playbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// 플레이백 중지
    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    /// 프레임 자동 진행 (플레이백 중)
    private func advanceFrame() {
        guard let delegate = delegate else { return }

        if delegate.currentFrameIndex < delegate.totalFrames - 1 {
            delegate.currentFrameIndex += 1
        } else if settings.isLooping {
            delegate.currentFrameIndex = 0
        } else {
            pause()
            return
        }
        delegate.loadFrame(at: delegate.currentFrameIndex)
    }

    // MARK: - Cleanup

    deinit {
        // Note: deinit은 nonisolated context이므로 직접 타이머 무효화
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}
