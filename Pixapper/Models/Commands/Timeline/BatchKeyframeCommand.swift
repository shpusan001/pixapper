//
//  BatchKeyframeCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

enum KeyframeOperation: String {
    case toggle = "Toggle Keyframe"
    case extend = "Extend Frame"
    case insertBlank = "Insert Blank Keyframe"
    case clear = "Clear Content"
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
