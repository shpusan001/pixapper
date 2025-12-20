//
//  DeleteFramesCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import Foundation
import SwiftUI

/// 프레임 삭제 Command
class DeleteFramesCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let layerId: UUID
    private let frameIndices: Set<Int>
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0
    private var deletedKeyframes: [Int: PixelGrid] = [:]

    var description: String {
        "Delete frames"
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

        // 단일 프레임 유지 검증
        guard timelineViewModel.totalFrames - frameIndices.count >= 1 else {
            return  // 최소 1개 프레임은 남겨야 함
        }

        // 이전 상태 저장
        previousTotalFrames = timelineViewModel.totalFrames
        previousCurrentFrameIndex = timelineViewModel.currentFrameIndex

        // 삭제할 키프레임들 백업 (원본 인덱스로)
        let sortedIndices = frameIndices.sorted()
        for frameIndex in sortedIndices {
            if timelineViewModel.layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex),
               let pixels = timelineViewModel.layerViewModel.layers[layerIndex].timeline.getKeyframe(at: frameIndex) {
                deletedKeyframes[frameIndex] = pixels
            }
        }

        // 뒤에서부터 역순으로 삭제 (인덱스 불일치 방지)
        // 각 삭제 후 즉시 shift 적용 (TimelineViewModel.deleteSelectedFrames 방식)
        let reversedIndices = sortedIndices.reversed()
        for frameIndex in reversedIndices {
            // 키프레임 제거
            if timelineViewModel.layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex) {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: frameIndex)
            }

            // 해당 프레임 이후의 키프레임들을 -1씩 앞으로 당김
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: frameIndex, by: -1)
        }

        timelineViewModel.updateTotalFrames()

        // currentFrameIndex 범위 검증
        let validIndex = min(timelineViewModel.currentFrameIndex, max(0, timelineViewModel.totalFrames - 1))
        timelineViewModel.selectFrame(at: validIndex, clearSelection: false)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId) else {
            return
        }

        // execute의 역순으로 복원
        // execute에서 역순으로 삭제했으므로, undo에서는 정순으로 복원
        let sortedIndices = frameIndices.sorted()

        for frameIndex in sortedIndices {
            // 1. 해당 프레임 이후의 키프레임들을 +1씩 뒤로 이동 (shift 취소)
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: frameIndex - 1, by: 1)

            // 2. 백업된 키프레임 복원 (있는 경우에만)
            if let pixels = deletedKeyframes[frameIndex] {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: pixels)
            }
        }

        // 상태 복원
        timelineViewModel.updateTotalFrames()

        // currentFrameIndex 범위 검증
        let validIndex = min(previousCurrentFrameIndex, max(0, timelineViewModel.totalFrames - 1))
        timelineViewModel.selectFrame(at: validIndex, clearSelection: false)
    }
}
