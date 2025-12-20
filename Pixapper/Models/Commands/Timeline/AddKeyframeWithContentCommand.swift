//
//  AddKeyframeWithContentCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 키프레임 추가 Command (현재 내용 포함)
class AddKeyframeWithContentCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let layerId: UUID
    private var insertedIndex: Int?
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0
    private var shiftedKeyframes: [Int: PixelGrid] = [:]
    private var insertedPixels: PixelGrid?

    var description: String {
        "Add keyframe with content"
    }

    init(timelineViewModel: TimelineViewModel, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
        self.layerId = layerId
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId) else {
            return
        }

        // 이전 상태 저장
        previousTotalFrames = timelineViewModel.totalFrames
        previousCurrentFrameIndex = timelineViewModel.currentFrameIndex

        // 현재 레이어의 픽셀을 PixelStateManager에서 가져오기
        guard let currentPixels = timelineViewModel.pixelStateManager.getPixels(layerId: layerId) else { return }
        insertedPixels = currentPixels

        // 현재 프레임 다음에 삽입할 위치
        insertedIndex = timelineViewModel.currentFrameIndex + 1

        // shift 전에 이동될 키프레임들 백업
        shiftedKeyframes = timelineViewModel.layerViewModel.layers[layerIndex].timeline.backupKeyframesAfter(timelineViewModel.currentFrameIndex)

        // 현재 레이어의 insertIndex 이후 키프레임만 shift
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: timelineViewModel.currentFrameIndex, by: 1)

        // 현재 레이어의 픽셀을 새 키프레임으로 저장
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: insertedIndex!, pixels: currentPixels)

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

        // execute의 역순으로 실행:

        // 1. 삽입된 키프레임 제거
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: inserted)

        // 2. shift 되돌리기 (shiftKeyframes가 원래 위치로 이동시키므로 백업 복원 불필요)
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: previousCurrentFrameIndex, by: -1)

        // 3. 상태 복원
        timelineViewModel.updateTotalFrames()

        // currentFrameIndex 범위 검증
        let validIndex = min(previousCurrentFrameIndex, max(0, timelineViewModel.totalFrames - 1))
        timelineViewModel.selectFrame(at: validIndex, clearSelection: false)
    }
}
