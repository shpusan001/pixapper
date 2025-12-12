//
//  ExtendFrameCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 프레임 연장 Command (F5)
/// - Note: 현재 레이어의 키프레임 span을 1프레임 연장하고, 뒤의 키프레임들을 밀어냄
class ExtendFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let frameIndex: Int
    private let layerId: UUID
    private var spanEnd: Int?
    private var shiftedKeyframes: [Int: [[Color?]]] = [:]  // 이동된 키프레임 백업
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0

    var description: String {
        "Extend frame at \(frameIndex)"
    }

    init(timelineViewModel: TimelineViewModel, frameIndex: Int, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
        self.frameIndex = frameIndex
        self.layerId = layerId
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        // 이전 상태 저장
        previousTotalFrames = timelineViewModel.totalFrames
        previousCurrentFrameIndex = timelineViewModel.currentFrameIndex

        let layer = timelineViewModel.layerViewModel.layers[layerIndex]

        // span 정보 가져오기
        guard let span = layer.timeline.getKeyframeSpan(at: frameIndex, totalFrames: timelineViewModel.totalFrames) else {
            return
        }

        let endIndex = span.start + span.length - 1
        spanEnd = endIndex

        // spanEnd 이후의 모든 키프레임 백업 (Undo용)
        let allKeyframeIndices = layer.timeline.getAllKeyframeIndices()
        for keyframeIndex in allKeyframeIndices {
            if keyframeIndex > endIndex {
                if let pixels = layer.timeline.getEffectivePixels(at: keyframeIndex) {
                    shiftedKeyframes[keyframeIndex] = pixels
                }
            }
        }

        // spanEnd 이후 키프레임들을 +1 이동
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: endIndex, by: 1)

        // 마지막 키프레임인 경우 (shift할 키프레임이 없는 경우)
        // 키프레임 없이 span만 1 프레임 확장
        if shiftedKeyframes.isEmpty {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setSpanEnd(at: endIndex + 1)
        }

        // totalFrames 자동 업데이트 (max 비교로 유지 또는 증가)
        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: timelineViewModel.currentFrameIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId),
              let originalSpanEnd = spanEnd else {
            return
        }

        // 마지막 키프레임이었을 경우 span 축소
        if shiftedKeyframes.isEmpty {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shrinkSpanEnd(by: 1)
        } else {
            // 이동된 키프레임들을 -1로 다시 이동
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: originalSpanEnd, by: -1)

            // 백업된 키프레임 복원
            for (originalIndex, pixels) in shiftedKeyframes {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: originalIndex, pixels: pixels)
            }
        }

        // totalFrames 복원
        timelineViewModel.totalFrames = previousTotalFrames

        // currentFrameIndex 복원
        if previousCurrentFrameIndex < timelineViewModel.totalFrames {
            timelineViewModel.currentFrameIndex = previousCurrentFrameIndex
        }

        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: timelineViewModel.currentFrameIndex)
    }
}
