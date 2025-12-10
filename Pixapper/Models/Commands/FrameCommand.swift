//
//  FrameCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import SwiftUI

/// 프레임 추가 Command
/// - Note: Deprecated - 더 이상 사용되지 않음. addKeyframeWithContent 또는 addBlankKeyframeAtNext 사용 권장
@available(*, deprecated, message: "No longer used - use layer-specific keyframe operations instead")
class AddFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private var addedFrameIndex: Int?

    var description: String {
        "Add frame"
    }

    init(timelineViewModel: TimelineViewModel) {
        self.timelineViewModel = timelineViewModel
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }
        // Note: addFrame() is deprecated but kept for backward compatibility
        timelineViewModel.addFrame()
        addedFrameIndex = timelineViewModel.currentFrameIndex
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let index = addedFrameIndex,
              index < timelineViewModel.totalFrames else {
            return
        }
        timelineViewModel.deleteFrame(at: index)
    }
}

/// 프레임 삭제 Command
class DeleteFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let deletedIndex: Int
    private var previousFrameIndex: Int
    private var previousTotalFrames: Int
    // 삭제된 프레임의 키프레임 데이터 백업 (레이어별)
    private var deletedKeyframeData: [UUID: [[Color?]]] = [:]

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

        // totalFrames 복원
        timelineViewModel.totalFrames = previousTotalFrames

        // 백업된 키프레임 데이터 복원
        for (layerId, pixels) in deletedKeyframeData {
            if let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) {
                timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: deletedIndex, pixels: pixels)
            }
        }

        // 이전 프레임 위치로 복원
        timelineViewModel.selectFrame(at: previousFrameIndex)
    }
}

/// 프레임 복제 Command
class DuplicateFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let sourceIndex: Int
    private var duplicatedFrameIndex: Int?

    var description: String {
        "Duplicate frame \(sourceIndex)"
    }

    init(timelineViewModel: TimelineViewModel, sourceIndex: Int) {
        self.timelineViewModel = timelineViewModel
        self.sourceIndex = sourceIndex
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }
        timelineViewModel.duplicateFrame(at: sourceIndex)
        duplicatedFrameIndex = timelineViewModel.currentFrameIndex
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let index = duplicatedFrameIndex,
              index < timelineViewModel.totalFrames else {
            return
        }
        timelineViewModel.deleteFrame(at: index)
    }
}
