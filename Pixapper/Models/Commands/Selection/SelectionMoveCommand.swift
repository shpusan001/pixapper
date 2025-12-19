//
//  SelectionMoveCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 선택 영역 이동 커맨드 (선택 상태 + 레이어 픽셀 변경 포함)
class SelectionMoveCommand: LayerPixelApplicable {
    private weak var canvasViewModel: CanvasViewModel?
    weak var layerViewModel: LayerViewModel?
    weak var timelineViewModel: TimelineViewModel?
    let layerIndex: Int

    // 이동 전 상태
    private let oldRect: CGRect
    private let oldPixels: PixelGrid
    private let oldOriginalRect: CGRect
    private let oldOriginalPixels: PixelGrid
    private let oldMask: [[Bool]]?

    // 이동 후 상태
    private let newRect: CGRect
    private let newPixels: PixelGrid
    private let newMask: [[Bool]]?

    // 레이어 픽셀 변경 정보
    private var layerOldPixels: [PixelChange] = []
    private var layerNewPixels: [PixelChange] = []

    var description: String {
        return "Move Selection"
    }

    init(
        canvasViewModel: CanvasViewModel,
        layerViewModel: LayerViewModel,
        timelineViewModel: TimelineViewModel?,
        layerIndex: Int,
        oldRect: CGRect,
        oldPixels: PixelGrid,
        oldOriginalRect: CGRect,
        oldOriginalPixels: PixelGrid,
        oldMask: [[Bool]]?,
        newRect: CGRect,
        newPixels: PixelGrid,
        newMask: [[Bool]]?
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.timelineViewModel = timelineViewModel
        self.layerIndex = layerIndex
        self.oldRect = oldRect
        self.oldPixels = oldPixels
        self.oldOriginalRect = oldOriginalRect
        self.oldOriginalPixels = oldOriginalPixels
        self.oldMask = oldMask
        self.newRect = newRect
        self.newPixels = newPixels
        self.newMask = newMask

        // 레이어 픽셀 변경 계산
        let changes = canvasViewModel.calculatePixelChanges(
            pixels: newPixels,
            origPixels: oldOriginalPixels,
            from: oldOriginalRect,
            to: newRect,
            layerIndex: layerIndex
        )
        layerOldPixels = changes.old
        layerNewPixels = changes.new
    }

    func execute() {
        // 레이어에 픽셀 적용
        applyPixelChanges(layerNewPixels)

        // 선택 상태 업데이트
        canvasViewModel?.selectionRect = newRect
        canvasViewModel?.selectionPixels = newPixels
        canvasViewModel?.originalRect = newRect
        canvasViewModel?.originalPixels = newPixels
        canvasViewModel?.freeformMask = newMask
    }

    func undo() {
        // 레이어 복원
        applyPixelChanges(layerOldPixels)

        // 선택 상태 복원
        canvasViewModel?.selectionRect = oldRect
        canvasViewModel?.selectionPixels = oldPixels
        canvasViewModel?.originalRect = oldOriginalRect
        canvasViewModel?.originalPixels = oldOriginalPixels
        canvasViewModel?.freeformMask = oldMask
    }
}
