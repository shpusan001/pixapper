//
//  DeleteFrameCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 프레임 삭제 Command
class DeleteFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let deletedIndex: Int
    private var previousFrameIndex: Int
    private var previousTotalFrames: Int
    // 삭제된 프레임의 키프레임 데이터 백업 (레이어별)
    private var deletedKeyframeData: [UUID: PixelGrid] = [:]

    var description: String {
        "Delete frame at index \(deletedIndex)"
    }

    init(timelineViewModel: TimelineViewModel, index: Int) {
        self.timelineViewModel = timelineViewModel
        self.deletedIndex = index
        self.previousFrameIndex = timelineViewModel.currentFrameIndex
        self.previousTotalFrames = timelineViewModel.totalFrames

        // 삭제 전에 키프레임 데이터 백업
        for layer in timelineViewModel.layerViewModel.layers {
            if layer.timeline.isKeyframe(at: index) {
                if let pixels = layer.timeline.getEffectivePixels(at: index) {
                    deletedKeyframeData[layer.id] = pixels
                }
            }
        }
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }
        timelineViewModel.deleteFrame(at: deletedIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel else { return }

        // execute의 deleteFrame 로직을 역순으로 실행:
        // deleteFrame에서 모든 레이어에 대해 shiftKeyframes(after: index, by: -1) 실행했으므로
        // undo에서는 모든 레이어에 대해 shiftKeyframes(after: deletedIndex - 1, by: 1) 실행

        for layerIndex in timelineViewModel.layerViewModel.layers.indices {
            // 1. shift 취소 (deletedIndex 이후를 +1씩 뒤로 이동)
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: deletedIndex - 1, by: 1)
        }

        // 2. 백업된 키프레임 데이터 복원
        for (layerId, pixels) in deletedKeyframeData {
            if let layerIndex = timelineViewModel.getLayerIndex(for: layerId) {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: deletedIndex, pixels: pixels)
            }
        }

        // 3. totalFrames 업데이트 (자동 계산)
        timelineViewModel.updateTotalFrames()

        // 4. 이전 프레임 위치로 복원 (범위 검증 포함)
        let validIndex = min(previousFrameIndex, max(0, timelineViewModel.totalFrames - 1))
        timelineViewModel.selectFrame(at: validIndex, clearSelection: false)
    }
}
