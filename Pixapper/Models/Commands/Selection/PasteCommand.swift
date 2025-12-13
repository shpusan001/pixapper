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
    let layerIndex: Int

    // 이전 선택 상태 (undo 시 복원)
    private let previousSelectionRect: CGRect?
    private let previousSelectionPixels: [[Color?]]?
    private let previousOriginalPixels: [[Color?]]?
    private let previousOriginalRect: CGRect?
    private let previousIsFloating: Bool

    // 붙여넣은 선택 상태
    private let pastedSelectionRect: CGRect
    private let pastedSelectionPixels: [[Color?]]

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
        layerIndex: Int,
        previousSelectionRect: CGRect?,
        previousSelectionPixels: [[Color?]]?,
        previousOriginalPixels: [[Color?]]?,
        previousOriginalRect: CGRect?,
        previousIsFloating: Bool,
        pastedSelectionRect: CGRect,
        pastedSelectionPixels: [[Color?]]
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.layerIndex = layerIndex
        self.previousSelectionRect = previousSelectionRect
        self.previousSelectionPixels = previousSelectionPixels
        self.previousOriginalPixels = previousOriginalPixels
        self.previousOriginalRect = previousOriginalRect
        self.previousIsFloating = previousIsFloating
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
        }

        // 2. 붙여넣기 픽셀을 레이어에 바로 적용
        applyPixelChanges(newPastePixels)

        // 3. TimelineViewModel에 동기화 (타임라인 모드에서만)
        if let timeline = canvasViewModel?.timelineViewModel {
            timeline.syncCurrentLayerToKeyframe()
        }

        // 4. 선택 영역 클리어 (붙여넣기 후 floating selection을 만들지 않음)
        canvasViewModel?.clearSelection()
    }

    func undo() {
        // 1. 붙여넣기 픽셀을 레이어에서 제거
        applyPixelChanges(oldPastePixels)

        // 2. 이전 floating selection이 있었고 커밋되었다면, 커밋 전 레이어 상태로 복원
        if previousIsFloating, !oldCommitPixels.isEmpty {
            applyPixelChanges(oldCommitPixels)
        }

        // 3. TimelineViewModel에 동기화 (타임라인 모드에서만)
        if let timeline = canvasViewModel?.timelineViewModel {
            timeline.syncCurrentLayerToKeyframe()
        }

        // 4. 이전 선택 상태 복원
        canvasViewModel?.restoreSelectionState(
            rect: previousSelectionRect,
            pixels: previousSelectionPixels,
            originalPixels: previousOriginalPixels,
            originalRect: previousOriginalRect,
            isFloating: previousIsFloating
        )
    }
}
