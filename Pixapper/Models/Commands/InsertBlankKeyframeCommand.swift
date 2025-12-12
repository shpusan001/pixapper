//
//  InsertBlankKeyframeCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 빈 키프레임 삽입 Command (F7)
class InsertBlankKeyframeCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let frameIndex: Int
    private let layerId: UUID
    private var oldPixels: [[Color?]]?
    private var wasKeyframe: Bool = false

    var description: String {
        "Insert blank keyframe at \(frameIndex)"
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

        // 현재 상태 저장
        wasKeyframe = timelineViewModel.layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex)
        oldPixels = timelineViewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layerId)

        timelineViewModel.insertBlankKeyframe(frameIndex: frameIndex, layerId: layerId)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        if let pixels = oldPixels {
            if wasKeyframe {
                // 원래 키프레임이었으면 픽셀 복원
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: pixels)
            } else {
                // 원래 키프레임이 아니었으면 제거
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: frameIndex)
            }
        }

        // 현재 프레임이면 화면 갱신
        if frameIndex == timelineViewModel.currentFrameIndex {
            timelineViewModel.loadFrame(at: frameIndex)
        }
    }
}
