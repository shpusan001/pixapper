//
//  PasteCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 붙여넣기 작업을 캡슐화하는 Command (선택 상태 복원 지원)
class PasteCommand: Command {
    private weak var canvasViewModel: CanvasViewModel?
    private weak var layerViewModel: LayerViewModel?
    private let layerIndex: Int

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
           let pixels = previousSelectionPixels,
           let origPixels = previousOriginalPixels {
            saveCommitPixelChanges(
                rect: rect,
                origRect: origRect,
                pixels: pixels,
                origPixels: origPixels,
                layerVM: layerViewModel,
                layerIdx: layerIndex
            )
        }
    }

    private func saveCommitPixelChanges(
        rect: CGRect,
        origRect: CGRect,
        pixels: [[Color?]],
        origPixels: [[Color?]],
        layerVM: LayerViewModel,
        layerIdx: Int
    ) {
        guard layerIdx < layerVM.layers.count else { return }

        // 1. 원본 위치에서 제거될 픽셀들
        let origStartX = Int(origRect.minX)
        let origStartY = Int(origRect.minY)

        for y in 0..<origPixels.count {
            for x in 0..<origPixels[y].count {
                if origPixels[y][x] != nil {
                    let pixelX = origStartX + x
                    let pixelY = origStartY + y
                    if pixelX >= 0 && pixelX < layerVM.layers[layerIdx].pixels[0].count &&
                       pixelY >= 0 && pixelY < layerVM.layers[layerIdx].pixels.count {
                        let oldColor = layerVM.layers[layerIdx].getPixel(x: pixelX, y: pixelY)
                        oldLayerPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        newLayerPixels.append(PixelChange(x: pixelX, y: pixelY, color: nil))
                    }
                }
            }
        }

        // 2. 새 위치에 추가될 픽셀들
        let startX = Int(rect.minX)
        let startY = Int(rect.minY)

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x] {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < layerVM.layers[layerIdx].pixels[0].count &&
                       pixelY >= 0 && pixelY < layerVM.layers[layerIdx].pixels.count {
                        let oldColor = layerVM.layers[layerIdx].getPixel(x: pixelX, y: pixelY)
                        if !oldLayerPixels.contains(where: { $0.x == pixelX && $0.y == pixelY }) {
                            oldLayerPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        }
                        newLayerPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                    }
                }
            }
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

    private func applyPixelChanges(_ changes: [PixelChange]) {
        guard let layerVM = layerViewModel,
              layerIndex < layerVM.layers.count else { return }

        for change in changes {
            layerVM.layers[layerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }
    }
}
