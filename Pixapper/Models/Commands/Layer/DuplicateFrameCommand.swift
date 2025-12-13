//
//  DuplicateFrameCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

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
