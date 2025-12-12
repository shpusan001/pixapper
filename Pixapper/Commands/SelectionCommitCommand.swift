//
//  SelectionCommitCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 선택 영역 커밋 커맨드 (레이어에 픽셀 배치 + 선택 상태 해제)
class SelectionCommitCommand: Command {
    private weak var canvasViewModel: CanvasViewModel?
    private weak var layerViewModel: LayerViewModel?
    private let layerIndex: Int

    // 커밋 전 상태 (floating 선택 있음)
    private let oldRect: CGRect
    private let oldPixels: [[Color?]]
    private let oldOriginalRect: CGRect
    private let oldOriginalPixels: [[Color?]]

    // 레이어 픽셀 변경 (새 위치에 배치)
    private let layerOldPixels: [PixelChange]
    private let layerNewPixels: [PixelChange]

    var description: String {
        return "Commit Selection"
    }

    init(
        canvasViewModel: CanvasViewModel,
        layerViewModel: LayerViewModel,
        layerIndex: Int,
        oldRect: CGRect,
        oldPixels: [[Color?]],
        oldOriginalRect: CGRect,
        oldOriginalPixels: [[Color?]],
        layerOldPixels: [PixelChange],
        layerNewPixels: [PixelChange]
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.layerIndex = layerIndex
        self.oldRect = oldRect
        self.oldPixels = oldPixels
        self.oldOriginalRect = oldOriginalRect
        self.oldOriginalPixels = oldOriginalPixels
        self.layerOldPixels = layerOldPixels
        self.layerNewPixels = layerNewPixels
    }

    func execute() {
        // 1. 레이어에 픽셀 배치
        applyPixelChanges(layerNewPixels)

        // 2. 선택 상태 해제
        canvasViewModel?.clearSelection()
    }

    func undo() {
        // 1. 레이어 픽셀 제거
        applyPixelChanges(layerOldPixels)

        // 2. 선택 상태 복원 (다시 floating 상태로)
        canvasViewModel?.selectionRect = oldRect
        canvasViewModel?.selectionPixels = oldPixels
        canvasViewModel?.originalRect = oldOriginalRect
        canvasViewModel?.originalPixels = oldOriginalPixels
        canvasViewModel?.isFloatingSelection = true
    }

    private func applyPixelChanges(_ changes: [PixelChange]) {
        guard let layerVM = layerViewModel,
              layerIndex < layerVM.layers.count else { return }

        for change in changes {
            layerVM.layers[layerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }
    }
}
