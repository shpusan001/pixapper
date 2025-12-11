//
//  KeyframeCommand.swift
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

        spanEnd = span.start + span.length - 1

        // spanEnd 이후의 모든 키프레임 백업 (Undo용)
        let allKeyframeIndices = layer.timeline.getAllKeyframeIndices()
        for keyframeIndex in allKeyframeIndices {
            if keyframeIndex > spanEnd! {
                if let pixels = layer.timeline.getEffectivePixels(at: keyframeIndex) {
                    shiftedKeyframes[keyframeIndex] = pixels
                }
            }
        }

        // spanEnd 이후 키프레임들을 +1 이동
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: spanEnd!, by: 1)

        // 마지막 키프레임인 경우 (shift할 키프레임이 없는 경우)
        // 키프레임 없이 span만 1 프레임 확장
        if shiftedKeyframes.isEmpty {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setSpanEnd(at: spanEnd! + 1)
        }

        // totalFrames 자동 업데이트 (max 비교로 유지 또는 증가)
        timelineViewModel.updateTotalFrames()
        timelineViewModel.loadFrame(at: timelineViewModel.currentFrameIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }),
              let end = spanEnd else {
            return
        }

        // 마지막 키프레임이었을 경우 span 축소
        if shiftedKeyframes.isEmpty {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shrinkSpanEnd(by: 1)
        } else {
            // 이동된 키프레임들을 -1로 다시 이동
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: end, by: -1)

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
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }),
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

/// 배치 키프레임 Command (다중 선택 지원)
class BatchKeyframeCommand: Command {
    private var commands: [Command] = []
    private let operationDescription: String

    var description: String {
        operationDescription
    }

    init(frameIndices: Set<Int>, layerId: UUID, timelineViewModel: TimelineViewModel, operation: KeyframeOperation) {
        self.operationDescription = "\(operation.rawValue) on \(frameIndices.count) frame(s)"

        // extend 작업은 역순으로 처리 (뒤에서부터 extend해야 앞 프레임에 영향 없음)
        let sortedIndices = operation == .extend ? frameIndices.sorted(by: >) : frameIndices.sorted()

        for frameIndex in sortedIndices {
            switch operation {
            case .toggle:
                commands.append(ToggleKeyframeCommand(timelineViewModel: timelineViewModel, frameIndex: frameIndex, layerId: layerId))
            case .extend:
                commands.append(ExtendFrameCommand(timelineViewModel: timelineViewModel, frameIndex: frameIndex, layerId: layerId))
            case .insertBlank:
                commands.append(InsertBlankKeyframeCommand(timelineViewModel: timelineViewModel, frameIndex: frameIndex, layerId: layerId))
            case .clear:
                commands.append(ClearFrameContentCommand(timelineViewModel: timelineViewModel, frameIndex: frameIndex, layerId: layerId))
            }
        }
    }

    func execute() {
        commands.forEach { $0.execute() }
    }

    func undo() {
        commands.reversed().forEach { $0.undo() }
    }
}

enum KeyframeOperation: String {
    case toggle = "Toggle Keyframe"
    case extend = "Extend Frame"
    case insertBlank = "Insert Blank Keyframe"
    case clear = "Clear Content"
}

/// 키프레임 추가 Command (현재 내용 포함)
class AddKeyframeWithContentCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let layerId: UUID
    private var insertedIndex: Int?
    private var previousTotalFrames: Int = 0
    private var previousCurrentFrameIndex: Int = 0
    private var shiftedKeyframes: [Int: [[Color?]]] = [:]
    private var insertedPixels: [[Color?]]?

    var description: String {
        "Add keyframe with content"
    }

    init(timelineViewModel: TimelineViewModel, layerId: UUID) {
        self.timelineViewModel = timelineViewModel
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

        // 현재 레이어의 픽셀을 미리 저장
        let currentPixels = timelineViewModel.layerViewModel.layers[layerIndex].pixels
        insertedPixels = currentPixels

        // 현재 프레임 다음에 삽입할 위치
        insertedIndex = timelineViewModel.currentFrameIndex + 1

        // shift 전에 이동될 키프레임들 백업
        let allKeyframeIndices = timelineViewModel.layerViewModel.layers[layerIndex].timeline.getAllKeyframeIndices()
        for keyframeIndex in allKeyframeIndices {
            if keyframeIndex > timelineViewModel.currentFrameIndex {
                if let pixels = timelineViewModel.layerViewModel.layers[layerIndex].timeline.getEffectivePixels(at: keyframeIndex) {
                    shiftedKeyframes[keyframeIndex] = pixels
                }
            }
        }

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
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }),
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
        let emptyPixels = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)

        // 현재 프레임 다음에 삽입할 위치
        insertedIndex = timelineViewModel.currentFrameIndex + 1

        // shift 전에 이동될 키프레임들 백업
        let allKeyframeIndices = timelineViewModel.layerViewModel.layers[layerIndex].timeline.getAllKeyframeIndices()
        for keyframeIndex in allKeyframeIndices {
            if keyframeIndex > timelineViewModel.currentFrameIndex {
                if let pixels = timelineViewModel.layerViewModel.layers[layerIndex].timeline.getEffectivePixels(at: keyframeIndex) {
                    shiftedKeyframes[keyframeIndex] = pixels
                }
            }
        }

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
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }),
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
