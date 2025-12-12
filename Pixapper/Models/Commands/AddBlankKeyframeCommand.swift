//
//  AddBlankKeyframeCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 빈 키프레임 추가 Command
class AddBlankKeyframeCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let layerId: UUID
    private var insertedIndex: Int?
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0
    private var shiftedKeyframes: [Int: [[Color?]]] = [:]
    private let canvasWidth: Int
    private let canvasHeight: Int

    var description: String {
        "Add blank keyframe"
    }

    init(timelineViewModel: TimelineViewModel, layerId: UUID, canvasWidth: Int, canvasHeight: Int) {
        self.timelineViewModel = timelineViewModel
        self.layerId = layerId
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        // 이전 상태 저장
        previousTotalFrames = timelineViewModel.totalFrames
        previousCurrentFrameIndex = timelineViewModel.currentFrameIndex

        // 빈 픽셀 미리 생성
        let emptyPixels = Layer.createEmptyPixels(width: canvasWidth, height: canvasHeight)

        // 현재 프레임 다음에 삽입할 위치
        insertedIndex = timelineViewModel.currentFrameIndex + 1

        // shift 전에 이동될 키프레임들 백업
        shiftedKeyframes = timelineViewModel.layerViewModel.layers[layerIndex].timeline.backupKeyframesAfter(timelineViewModel.currentFrameIndex)

        // 현재 레이어의 insertIndex 이후 키프레임만 shift
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: timelineViewModel.currentFrameIndex, by: 1)

        // 빈 픽셀로 새 키프레임 생성
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: insertedIndex!, pixels: emptyPixels)

        // 새 프레임으로 이동
        timelineViewModel.currentFrameIndex = insertedIndex!

        // totalFrames 자동 업데이트
        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: insertedIndex!)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId),
              let inserted = insertedIndex else {
            return
        }

        // 삽입된 키프레임 제거
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: inserted)

        // shift된 키프레임들을 다시 -1로 이동
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: previousCurrentFrameIndex, by: -1)

        // 백업된 키프레임 복원
        for (originalIndex, pixels) in shiftedKeyframes {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: originalIndex, pixels: pixels)
        }

        // totalFrames 복원
        timelineViewModel.totalFrames = previousTotalFrames

        // currentFrameIndex 복원
        timelineViewModel.currentFrameIndex = previousCurrentFrameIndex

        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: previousCurrentFrameIndex)
    }
}
