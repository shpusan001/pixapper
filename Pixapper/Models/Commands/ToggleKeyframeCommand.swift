//
//  ToggleKeyframeCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 키프레임 토글 Command (F6)
class ToggleKeyframeCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let frameIndex: Int
    private let layerId: UUID
    private var wasKeyframe: Bool = false
    private var oldPixels: [[Color?]]?

    var description: String {
        "Toggle keyframe at frame \(frameIndex)"
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

        if wasKeyframe {
            oldPixels = timelineViewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layerId)
        }

        // 실행
        timelineViewModel.toggleKeyframe(frameIndex: frameIndex, layerId: layerId)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        if wasKeyframe {
            // 원래 키프레임이었으면 복원
            if let pixels = oldPixels {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: pixels)
            }
        } else {
            // 원래 키프레임이 아니었으면 제거
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: frameIndex)
        }
    }
}
