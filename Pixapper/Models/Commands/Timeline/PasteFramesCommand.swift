//
//  PasteFramesCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import Foundation
import SwiftUI

/// 프레임 붙여넣기 Command
class PasteFramesCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let layerId: UUID
    private let startIndex: Int
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0
    private var shiftedKeyframes: [Int: PixelGrid] = [:]
    private var pastedFrameCount: Int = 0
    private var pastedKeyframes: [Int: PixelGrid] = [:]

    var description: String {
        "Paste frames"
    }

    init(timelineViewModel: TimelineViewModel, startIndex: Int, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
        self.startIndex = startIndex
        self.layerId = layerId
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId),
              !timelineViewModel.frameClipboard.isEmpty else {
            return
        }

        // 이전 상태 저장
        previousTotalFrames = timelineViewModel.totalFrames
        previousCurrentFrameIndex = timelineViewModel.currentFrameIndex
        pastedFrameCount = timelineViewModel.frameClipboard.frameCount

        // shift 전에 이동될 키프레임들 백업
        shiftedKeyframes = timelineViewModel.layerViewModel.layers[layerIndex].timeline.backupKeyframesAfter(startIndex - 1)

        // startIndex 이후의 키프레임들을 frameCount만큼 뒤로 이동
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: startIndex - 1, by: pastedFrameCount)

        // 클립보드의 키프레임들을 붙여넣기
        for (relativeIndex, pixels) in timelineViewModel.frameClipboard.keyframes {
            let targetIndex = startIndex + relativeIndex
            pastedKeyframes[targetIndex] = pixels
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: targetIndex, pixels: pixels)
        }

        // 붙여넣은 첫 번째 프레임으로 이동
        timelineViewModel.currentFrameIndex = startIndex
        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: startIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId) else {
            return
        }

        // 붙여넣은 키프레임들 제거
        for targetIndex in pastedKeyframes.keys {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: targetIndex)
        }

        // shift된 키프레임들을 원래 위치로 복원
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: startIndex - 1, by: -pastedFrameCount)

        // 백업된 키프레임 복원
        for (originalIndex, pixels) in shiftedKeyframes {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: originalIndex, pixels: pixels)
        }

        // 상태 복원
        timelineViewModel.totalFrames = previousTotalFrames
        timelineViewModel.currentFrameIndex = previousCurrentFrameIndex
        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: previousCurrentFrameIndex)
    }
}
