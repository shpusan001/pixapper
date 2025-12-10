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

        // shift를 했으므로 타임라인 전체 길이 증가 (중간이든 끝이든)
        if spanEnd! + 1 < timelineViewModel.totalFrames {
            // 중간: 기존 프레임들을 밀었으므로 공간 1칸 추가
            timelineViewModel.totalFrames += 1
        } else {
            // 끝: spanEnd + 2까지 확장 (span 끝 + 연장된 1칸)
            timelineViewModel.totalFrames = spanEnd! + 2
        }

        timelineViewModel.updateTotalFrames()
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let layerIndex = timelineViewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }),
              let end = spanEnd else {
            return
        }

        // 이동된 키프레임들을 -1로 다시 이동
        timelineViewModel.layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: end, by: -1)

        // 백업된 키프레임 복원 (혹시 데이터 손실 방지)
        for (originalIndex, pixels) in shiftedKeyframes {
            timelineViewModel.layerViewModel.layers[layerIndex].timeline.setKeyframe(at: originalIndex, pixels: pixels)
        }

        timelineViewModel.updateTotalFrames()
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
