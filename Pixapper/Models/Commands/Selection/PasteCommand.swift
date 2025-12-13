//
//  PasteCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 붙여넣기 작업을 캡슐화하는 Command (선택 상태 복원 지원)
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

    // 붙여넣은 선택 상태 (redo 시 복원)
    private let pastedSelectionRect: CGRect
    private let pastedSelectionPixels: [[Color?]]

    // 이전 선택을 커밋할 때의 픽셀 변경 정보 (커밋 전 레이어 상태 → 커밋 후)
    private var oldLayerPixels: [PixelChange] = []  // 커밋 전 레이어 픽셀
    private var newLayerPixels: [PixelChange] = []  // 커밋 후 레이어 픽셀 (이전 선택 적용)

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
            oldLayerPixels = changes.old
            newLayerPixels = changes.new
        }
    }

    func execute() {
        // 이전 선택이 floating이었다면, 레이어에 커밋
        if previousIsFloating, !newLayerPixels.isEmpty {
            applyPixelChanges(newLayerPixels)
        }

        // 붙여넣은 선택 상태 복원
        canvasViewModel?.restoreSelectionState(
            rect: pastedSelectionRect,
            pixels: pastedSelectionPixels,
            originalPixels: pastedSelectionPixels,
            originalRect: pastedSelectionRect,
            isFloating: true
        )
    }

    func undo() {
        // 이전 선택이 floating이었고 커밋되었다면, 커밋 전 레이어 상태로 복원
        if previousIsFloating, !oldLayerPixels.isEmpty {
            applyPixelChanges(oldLayerPixels)
        }

        // 이전 선택 상태 복원
        canvasViewModel?.restoreSelectionState(
            rect: previousSelectionRect,
            pixels: previousSelectionPixels,
            originalPixels: previousOriginalPixels,
            originalRect: previousOriginalRect,
            isFloating: previousIsFloating
        )
    }
}
