//
//  FrameCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 프레임 추가 Command
class AddFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private var addedFrameIndex: Int?
    private var addedFrame: Frame?

    var description: String {
        "Add frame"
    }

    init(timelineViewModel: TimelineViewModel) {
        self.timelineViewModel = timelineViewModel
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }
        timelineViewModel.addFrame()
        addedFrameIndex = timelineViewModel.currentFrameIndex
        if addedFrameIndex! < timelineViewModel.frames.count {
            addedFrame = timelineViewModel.frames[addedFrameIndex!]
        }
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let index = addedFrameIndex,
              index < timelineViewModel.frames.count else {
            return
        }
        timelineViewModel.deleteFrame(at: index)
    }
}

/// 프레임 삭제 Command
class DeleteFrameCommand: Command {
    private weak var timelineViewModel: TimelineViewModel?
    private let deletedIndex: Int
    private var deletedFrame: Frame?
    private var previousFrameIndex: Int

    var description: String {
        "Delete frame at index \(deletedIndex)"
    }

    init(timelineViewModel: TimelineViewModel, index: Int) {
        self.timelineViewModel = timelineViewModel
        self.deletedIndex = index
        self.previousFrameIndex = timelineViewModel.currentFrameIndex
        if index < timelineViewModel.frames.count {
            self.deletedFrame = timelineViewModel.frames[index]
        }
    }

    func execute() {
        guard let timelineViewModel = timelineViewModel else { return }
        timelineViewModel.deleteFrame(at: deletedIndex)
    }

    func undo() {
        guard let timelineViewModel = timelineViewModel,
              let frame = deletedFrame else {
            return
        }
        timelineViewModel.frames.insert(frame, at: deletedIndex)
        timelineViewModel.currentFrameIndex = previousFrameIndex
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
              index < timelineViewModel.frames.count else {
            return
        }
        timelineViewModel.deleteFrame(at: index)
    }
}
