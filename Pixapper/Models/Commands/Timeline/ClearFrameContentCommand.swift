//
//  ClearFrameContentCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 키프레임 내용 지우기 Command
class ClearFrameContentCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let frameIndex: Int
    private let layerId: UUID
    private var oldPixels: [[Color?]]?

    var description: String {
        "Clear frame content at \(frameIndex)"
    }

    init(timelineViewModel: TimelineViewModel, frameIndex: Int, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
        self.frameIndex = frameIndex
        self.layerId = layerId
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }

        // 이전 픽셀 저장
        oldPixels = timelineViewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layerId)

        timelineViewModel.clearFrameContent(frameIndex: frameIndex, layerId: layerId)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId),
              let pixels = oldPixels else {
            return
        }

        // 픽셀 복원
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: pixels)

        // 현재 프레임이면 화면 갱신
        if frameIndex == timelineViewModel.currentFrameIndex {
            timelineViewModel.layerViewModel.layers[layerIndex].pixels = pixels
        }
    }
}
