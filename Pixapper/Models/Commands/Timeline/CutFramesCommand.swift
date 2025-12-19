//
//  CutFramesCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import Foundation
import SwiftUI

/// 프레임 잘라내기 Command (복사 + 삭제)
class CutFramesCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let layerId: UUID
    private let frameIndices: Set<Int>
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0
    private var deletedKeyframes: [Int: PixelGrid] = [:]
    private var previousClipboard: FrameClipboard = .empty

    var description: String {
        "Cut frames"
    }

    init(timelineViewModel: TimelineViewModel, frameIndices: Set<Int>, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
        self.frameIndices = frameIndices
        self.layerId = layerId
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId),
              !frameIndices.isEmpty else {
            return
        }

        // 이전 상태 저장
        previousTotalFrames = timelineViewModel.totalFrames
        previousCurrentFrameIndex = timelineViewModel.currentFrameIndex
        previousClipboard = timelineViewModel.frameClipboard

        // 삭제할 키프레임들 백업
        let sortedIndices = frameIndices.sorted()
        for frameIndex in sortedIndices {
            if timelineViewModel.layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex),
               let pixels = timelineViewModel.layerViewModel.layers[layerIndex].timeline.getKeyframe(at: frameIndex) {
                deletedKeyframes[frameIndex] = pixels
            }
        }

        // 복사 (클립보드에 저장)
        timelineViewModel.copyFrames(frameIndices: frameIndices, layerId: layerId)

        // 삭제 (역순으로)
        let reversedIndices = sortedIndices.reversed()
        for frameIndex in reversedIndices {
            if timelineViewModel.layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex) {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: frameIndex)
            }
        }

        // 키프레임 재정렬
        let firstDeletedIndex = sortedIndices.first!
        let deletedCount = sortedIndices.count
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: firstDeletedIndex - 1, by: -deletedCount)

        // span 끝도 축소
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shrinkSpanEnd(by: deletedCount)

        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: timelineViewModel.currentFrameIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId) else {
            return
        }

        // 삭제된 프레임 개수만큼 뒤의 키프레임들을 뒤로 이동
        let sortedIndices = frameIndices.sorted()
        let firstDeletedIndex = sortedIndices.first!
        let deletedCount = sortedIndices.count

        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: firstDeletedIndex - 1, by: deletedCount)

        // 삭제된 키프레임들 복원
        for (frameIndex, pixels) in deletedKeyframes {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: pixels)
        }

        // 상태 복원
        timelineViewModel.totalFrames = previousTotalFrames
        timelineViewModel.currentFrameIndex = previousCurrentFrameIndex
        timelineViewModel.frameClipboard = previousClipboard

        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: previousCurrentFrameIndex)
    }
}
