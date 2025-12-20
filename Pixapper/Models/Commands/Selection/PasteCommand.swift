//
//  PasteCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 붙여넣기 작업을 캡슐화하는 Command
/// - 붙여넣기 시 바로 레이어에 픽셀을 적용하여 Undo/Redo 지원
class PasteCommand: LayerPixelApplicable {
    private weak var canvasViewModel: CanvasViewModel?
    weak var layerViewModel: LayerViewModel?
    weak var timelineViewModel: TimelineViewModel?
    let layerIndex: Int
    let frameIndex: Int

    // 이전 선택 상태 (undo 시 복원)
    private let previousSelectionRect: CGRect?
    private let previousSelectionPixels: PixelGrid?
    private let previousOriginalPixels: PixelGrid?
    private let previousOriginalRect: CGRect?
    private let previousIsFloating: Bool
    private let previousFreeformMask: [[Bool]]?

    // 붙여넣은 선택 상태
    private let pastedSelectionRect: CGRect
    private let pastedSelectionPixels: PixelGrid

    // 이전 선택을 커밋할 때의 픽셀 변경 정보
    private var oldCommitPixels: [PixelChange] = []
    private var newCommitPixels: [PixelChange] = []

    // 붙여넣기로 인한 픽셀 변경 정보
    private var oldPastePixels: [PixelChange] = []
    private var newPastePixels: [PixelChange] = []

    var description: String {
        return "Paste Selection"
    }

    init(
        canvasViewModel: CanvasViewModel,
        layerViewModel: LayerViewModel,
        timelineViewModel: TimelineViewModel?,
        layerIndex: Int,
        frameIndex: Int,
        previousSelectionRect: CGRect?,
        previousSelectionPixels: PixelGrid?,
        previousOriginalPixels: PixelGrid?,
        previousOriginalRect: CGRect?,
        previousIsFloating: Bool,
        previousFreeformMask: [[Bool]]?,
        pastedSelectionRect: CGRect,
        pastedSelectionPixels: PixelGrid
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.timelineViewModel = timelineViewModel
        self.layerIndex = layerIndex
        self.frameIndex = frameIndex
        self.previousSelectionRect = previousSelectionRect
        self.previousSelectionPixels = previousSelectionPixels
        self.previousOriginalPixels = previousOriginalPixels
        self.previousOriginalRect = previousOriginalRect
        self.previousIsFloating = previousIsFloating
        self.previousFreeformMask = previousFreeformMask
        self.pastedSelectionRect = pastedSelectionRect
        self.pastedSelectionPixels = pastedSelectionPixels

        // 이전 floating selection이 있었다면, 커밋 시 레이어 변경 정보 저장
        if previousIsFloating,
           let rect = previousSelectionRect,
           let origRect = previousOriginalRect,
           let pixels = previousSelectionPixels {
            let changes = canvasViewModel.calculatePixelChanges(
                pixels: pixels,
                origPixels: previousOriginalPixels,
                from: origRect,
                to: rect,
                layerIndex: layerIndex
            )
            oldCommitPixels = changes.old
            newCommitPixels = changes.new
        }

        // 붙여넣기로 인한 픽셀 변경 정보 계산
        let pasteChanges = canvasViewModel.calculatePixelChanges(
            pixels: pastedSelectionPixels,
            origPixels: pastedSelectionPixels,
            from: pastedSelectionRect,
            to: pastedSelectionRect,
            layerIndex: layerIndex
        )
        oldPastePixels = pasteChanges.old
        newPastePixels = pasteChanges.new
    }

    func execute() {
        // 1. 이전 floating selection이 있었다면, 레이어에 커밋
        if previousIsFloating, !newCommitPixels.isEmpty {
            applyPixelChanges(newCommitPixels)
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }

        // 2. 이전 selection 상태 완전히 클리어
        canvasViewModel?.clearSelection()

        // 3. 붙여넣기를 floating selection으로 설정 (바로 커밋하지 않음)
        guard !pastedSelectionPixels.isEmpty else { return }

        // 붙여넣기는 모든 픽셀이 선택된 상태의 마스크 생성 (전부 true)
        let mask = Array(repeating: Array(repeating: true, count: pastedSelectionPixels[0].count), count: pastedSelectionPixels.count)

        canvasViewModel?.setFloatingSelection(
            rect: pastedSelectionRect,
            pixels: pastedSelectionPixels,
            originalPixels: pastedSelectionPixels, // 붙여넣기는 원본과 동일
            originalRect: pastedSelectionRect,
            freeformMask: mask
        )
    }

    func undo() {
        // 1. 이전 floating selection이 있었고 커밋되었다면, 커밋 전 레이어 상태로 복원
        if previousIsFloating, !oldCommitPixels.isEmpty {
            applyPixelChanges(oldCommitPixels)
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }

        // 2. 이전 선택 상태 복원
        canvasViewModel?.restoreSelectionState(
            rect: previousSelectionRect,
            pixels: previousSelectionPixels,
            originalPixels: previousOriginalPixels,
            originalRect: previousOriginalRect,
            isFloating: previousIsFloating,
            freeformMask: previousFreeformMask
        )
    }
}
