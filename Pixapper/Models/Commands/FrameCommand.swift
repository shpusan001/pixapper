//
//  FrameCommand.swift
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
            if let layerIndex = timelineViewModel.getLayerIndex(for: layerId) {
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

/// 레이어별 프레임 삭제 Command (독립 동작)
class DeleteFrameInLayerCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let deletedIndex: Int
    private let layerId: UUID
    private var previousFrameIndex: Int
    private var previousTotalFrames: Int
    // 삭제된 키프레임 데이터 및 shift된 키프레임 백업
    private var deletedKeyframe: [[Color?]]?
    private var wasKeyframe: Bool = false
    private var shiftedKeyframes: [Int: [[Color?]]] = [:]

    var description: String {
        "Delete frame at index \(deletedIndex) in layer"
    }

    init(timelineViewModel: TimelineViewModel, index: Int, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
        self.deletedIndex = index
        self.layerId = layerId
        self.previousFrameIndex = timelineViewModel.currentFrameIndex
        self.previousTotalFrames = timelineViewModel.totalFrames

        // 삭제 전에 키프레임 데이터 백업
        if let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) {
            let layer = timelineViewModel.layerViewModel.layers[layerIndex]
            wasKeyframe = layer.timeline.isKeyframe(at: index)

            if wasKeyframe {
                deletedKeyframe = layer.timeline.getEffectivePixels(at: index)
            }

            // index 이후의 모든 키프레임 백업 (Undo용)
            let allKeyframeIndices = layer.timeline.getAllKeyframeIndices()
            for keyframeIndex in allKeyframeIndices {
                if keyframeIndex > index {
                    if let pixels = layer.timeline.getEffectivePixels(at: keyframeIndex) {
                        shiftedKeyframes[keyframeIndex] = pixels
                    }
                }
            }
        }
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }
        timelineViewModel.deleteFrameInCurrentLayer(at: deletedIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.getLayerIndex(for: layerId) else {
            return
        }

        // totalFrames 복원
        timelineViewModel.totalFrames = previousTotalFrames

        // 삭제된 키프레임이 있었으면 복원
        if wasKeyframe, let pixels = deletedKeyframe {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: deletedIndex, pixels: pixels)
        }

        // shift된 키프레임들을 +1로 다시 이동
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: deletedIndex - 1, by: 1)

        // 백업된 키프레임 복원
        for (originalIndex, pixels) in shiftedKeyframes {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: originalIndex, pixels: pixels)
        }

        // 이전 프레임 위치로 복원
        timelineViewModel.currentFrameIndex = previousFrameIndex
        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: previousFrameIndex)
    }
}
