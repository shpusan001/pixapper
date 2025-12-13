//
//  FillTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 채우기 도구
@MainActor
class FillTool: CanvasTool {
    private weak var canvasViewModel: CanvasViewModel?
    private let layerViewModel: LayerViewModel
    private let commandManager: CommandManager
    private let toolSettingsManager: ToolSettingsManager
    private weak var timelineViewModel: TimelineViewModel?

    init(
        canvasViewModel: CanvasViewModel,
        layerViewModel: LayerViewModel,
        commandManager: CommandManager,
        toolSettingsManager: ToolSettingsManager,
        timelineViewModel: TimelineViewModel?
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.commandManager = commandManager
        self.toolSettingsManager = toolSettingsManager
        self.timelineViewModel = timelineViewModel
    }

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        floodFill(
            x: x,
            y: y,
            fillColor: toolSettingsManager.fillSettings.color,
            tolerance: toolSettingsManager.fillSettings.tolerance
        )
    }

    func handleDrag(x: Int, y: Int) {
        // Fill tool은 드래그를 사용하지 않음
    }

    func handleUp(x: Int, y: Int) {
        // Fill tool은 down에서 완료됨
    }

    // MARK: - Private Methods

    private var currentLayerIndex: Int {
        layerViewModel.selectedLayerIndex
    }

    private func floodFill(x: Int, y: Int, fillColor: Color, tolerance: Double) {
        guard let canvas = canvasViewModel,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let layer = layerViewModel.layers[currentLayerIndex]
        let targetColor = layer.getPixel(x: x, y: y)

        // Don't fill if target and fill colors are the same (with tolerance)
        if colorsEqualWithTolerance(targetColor, fillColor, tolerance: tolerance) {
            return
        }

        var changedPixels: [PixelChange] = []
        var oldPixels: [PixelChange] = []
        var stack = [(x: Int, y: Int)]()
        stack.append((x, y))

        while !stack.isEmpty {
            let point = stack.removeLast()
            let px = point.x
            let py = point.y

            guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else {
                continue
            }

            let currentColor = layerViewModel.layers[currentLayerIndex].getPixel(x: px, y: py)
            if !colorsEqualWithTolerance(currentColor, targetColor, tolerance: tolerance) {
                continue
            }

            // 이전 상태 저장
            oldPixels.append(PixelChange(x: px, y: py, color: currentColor))
            changedPixels.append(PixelChange(x: px, y: py, color: fillColor))

            layerViewModel.layers[currentLayerIndex].setPixel(x: px, y: py, color: fillColor)

            stack.append((px + 1, py))
            stack.append((px - 1, py))
            stack.append((px, py + 1))
            stack.append((px, py - 1))
        }

        // Command 생성 (이미 실행된 상태)
        if !changedPixels.isEmpty {
            let command = DrawCommand(
                layerViewModel: layerViewModel,
                layerIndex: currentLayerIndex,
                oldPixels: oldPixels,
                newPixels: changedPixels
            )
            commandManager.addExecutedCommand(command)

            // Timeline에 동기화
            timelineViewModel?.syncCurrentLayerToKeyframe()
        }
    }

    /// 두 색상을 허용 오차(tolerance)와 함께 비교
    private func colorsEqualWithTolerance(_ c1: Color?, _ c2: Color?, tolerance: Double) -> Bool {
        if c1 == nil && c2 == nil {
            return true
        }
        guard let c1 = c1, let c2 = c2 else {
            return false
        }
        return c1.isEqual(to: c2, tolerance: tolerance)
    }
}
