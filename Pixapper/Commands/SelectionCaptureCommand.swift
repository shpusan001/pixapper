//
//  SelectionCaptureCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 선택 영역 생성 커맨드 (레이어에서 픽셀 제거 + 선택 상태 설정)
class SelectionCaptureCommand: Command {
    private weak var canvasViewModel: CanvasViewModel?
    private weak var layerViewModel: LayerViewModel?
    private let layerIndex: Int

    // 선택 전 상태 (선택 없음)
    private let wasFloating: Bool
    private let oldRect: CGRect?
    private let oldPixels: [[Color?]]?
    private let oldOriginalRect: CGRect?
    private let oldOriginalPixels: [[Color?]]?

    // 선택 후 상태
    private let newRect: CGRect
    private let newPixels: [[Color?]]

    // 레이어 픽셀 변경 (선택 영역에서 제거)
    private let layerOldPixels: [PixelChange]
    private let layerNewPixels: [PixelChange]

    var description: String {
        return "Capture Selection"
    }

    init(
        canvasViewModel: CanvasViewModel,
        layerViewModel: LayerViewModel,
        layerIndex: Int,
        wasFloating: Bool,
        oldRect: CGRect?,
        oldPixels: [[Color?]]?,
        oldOriginalRect: CGRect?,
        oldOriginalPixels: [[Color?]]?,
        newRect: CGRect,
        newPixels: [[Color?]],
        layerOldPixels: [PixelChange],
        layerNewPixels: [PixelChange]
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.layerIndex = layerIndex
        self.wasFloating = wasFloating
        self.oldRect = oldRect
        self.oldPixels = oldPixels
        self.oldOriginalRect = oldOriginalRect
        self.oldOriginalPixels = oldOriginalPixels
        self.newRect = newRect
        self.newPixels = newPixels
        self.layerOldPixels = layerOldPixels
        self.layerNewPixels = layerNewPixels
    }

    func execute() {
        // 1. 레이어에서 픽셀 제거
        applyPixelChanges(layerNewPixels)

        // 2. 선택 상태 설정
        canvasViewModel?.selectionRect = newRect
        canvasViewModel?.selectionPixels = newPixels
        canvasViewModel?.originalRect = newRect
        canvasViewModel?.originalPixels = newPixels
        canvasViewModel?.isFloatingSelection = true
    }

    func undo() {
        // 1. 레이어 픽셀 복원
        applyPixelChanges(layerOldPixels)

        // 2. 선택 상태 복원 (이전에 선택이 없었으면 nil로)
        canvasViewModel?.selectionRect = oldRect
        canvasViewModel?.selectionPixels = oldPixels
        canvasViewModel?.originalRect = oldOriginalRect
        canvasViewModel?.originalPixels = oldOriginalPixels
        canvasViewModel?.isFloatingSelection = wasFloating
    }

    private func applyPixelChanges(_ changes: [PixelChange]) {
        guard let layerVM = layerViewModel,
              layerIndex < layerVM.layers.count else { return }

        for change in changes {
            layerVM.layers[layerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }
    }
}
