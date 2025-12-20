//
//  FillTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 채우기 도구
@MainActor
class FillTool: BaseTool, CanvasTool {

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        floodFill(
            x: x,
            y: y,
            fillColor: toolSettingsManager.colorManager.primaryColor,
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

    private func floodFill(x: Int, y: Int, fillColor: Color, tolerance: Double) {
        guard let canvas = canvasViewModel,
              let timelineVM = timelineViewModel,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let layerId = layerViewModel.layers[currentLayerIndex].id
        guard let pixels = timelineVM.getCurrentFramePixels(layerId: layerId) else { return }

        // 시작점의 픽셀 값 가져오기
        guard y >= 0, y < pixels.count, x >= 0, x < pixels[y].count else { return }
        let targetValue = pixels[y][x]

        // Convert to Color for comparison
        let targetColor: Color
        switch targetValue {
        case .transparent:
            targetColor = .clear
        case .indexed(let colorIndex):
            targetColor = timelineViewModel?.pixelStateManager.currentPalette.getColor(at: colorIndex) ?? .clear
        case .gradient:
            targetColor = .clear
        }

        // Don't fill if target and fill colors are the same (with tolerance)
        if Color.areEqual(targetColor, fillColor, tolerance: tolerance) {
            return
        }

        // Convert fillColor to PixelValue
        let fillValue: PixelValue
        if let colorIndex = timelineViewModel?.pixelStateManager.currentPalette.findClosest(fillColor) {
            fillValue = .indexed(colorIndex)
        } else {
            fillValue = .transparent
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

            // 현재 픽셀 값 가져오기 (TimelineViewModel 사용)
            guard let currentPixels = timelineVM.getCurrentFramePixels(layerId: layerId),
                  py < currentPixels.count, px < currentPixels[py].count else {
                continue
            }
            let currentValue = currentPixels[py][px]

            // Convert current PixelValue to Color for comparison
            let currentColor: Color
            switch currentValue {
            case .transparent:
                currentColor = .clear
            case .indexed(let colorIndex):
                currentColor = timelineViewModel?.pixelStateManager.currentPalette.getColor(at: colorIndex) ?? .clear
            case .gradient:
                currentColor = .clear
            }

            if !Color.areEqual(currentColor, targetColor, tolerance: tolerance) {
                continue
            }

            // 이전 상태 저장
            oldPixels.append(PixelChange(x: px, y: py, value: currentValue))
            changedPixels.append(PixelChange(x: px, y: py, value: fillValue))

            // Timeline에 즉시 반영
            timelineVM.setPixel(layerId: layerId, x: px, y: py, value: fillValue)

            stack.append((px + 1, py))
            stack.append((px - 1, py))
            stack.append((px, py + 1))
            stack.append((px, py - 1))
        }

        // Command 생성 (이미 실행된 상태)
        if !changedPixels.isEmpty {
            let layerId = layerViewModel.layers[currentLayerIndex].id
            let command = DrawCommand(
                timelineViewModel: timelineViewModel,
                layerId: layerId,
                frameIndex: timelineVM.currentFrameIndex,
                oldPixels: oldPixels,
                newPixels: changedPixels
            )
            commandManager.addExecutedCommand(command)

            // Fill 완료 시 timeline에 즉시 동기화
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }
    }
}
