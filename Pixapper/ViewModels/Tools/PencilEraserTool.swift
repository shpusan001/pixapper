//
//  PencilEraserTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 그리기 도구 (연필, 지우개)
@MainActor
class PencilEraserTool: BaseTool, CanvasTool {
    // Drawing state
    private var lastDrawPoint: (x: Int, y: Int)?

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        lastDrawPoint = (x, y)
        beginStroke()
        drawPixel(x: x, y: y)
    }

    func handleDrag(x: Int, y: Int) {
        // 드래그 중에도 프리뷰 위치 업데이트
        canvasViewModel?.brushPreviewPosition = (x, y)

        // 보간을 통해 끊김 방지
        if let last = lastDrawPoint {
            drawInterpolatedLine(from: last, to: (x, y))
        } else {
            drawPixel(x: x, y: y)
        }
        lastDrawPoint = (x, y)
    }

    func handleUp(x: Int, y: Int) {
        finishStroke()
        lastDrawPoint = nil
    }

    func updateHover(x: Int, y: Int) {
        canvasViewModel?.brushPreviewPosition = (x, y)
    }

    func clearHover() {
        canvasViewModel?.brushPreviewPosition = nil
    }

    // MARK: - Private Methods

    private func drawPixel(x: Int, y: Int) {
        guard let canvas = canvasViewModel,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let color: Color?
        let brushSize: Int

        switch toolSettingsManager.selectedTool {
        case .pencil:
            color = toolSettingsManager.colorManager.primaryColor
            brushSize = toolSettingsManager.pencilSettings.brushSize
        case .eraser:
            color = nil
            brushSize = toolSettingsManager.eraserSettings.brushSize
        default:
            return
        }

        // 브러시 크기에 따라 여러 픽셀 그리기
        // 홀수: 정사각형, 짝수: 원형(맨해튼 거리)
        let radius = brushSize / 2
        for dy in -radius...radius {
            for dx in -radius...radius {
                let px = x + dx
                let py = y + dy

                // 캔버스 범위 체크
                guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else { continue }

                // 브러시 모양 결정
                let shouldDraw: Bool
                if brushSize % 2 == 1 {
                    // 홀수: 정사각형
                    shouldDraw = true
                } else {
                    // 짝수: 원형 (맨해튼 거리)
                    shouldDraw = abs(dx) + abs(dy) <= radius
                }
                guard shouldDraw else { continue }

                // 이미 그린 픽셀인지 체크 (보간 중 중복 방지)
                let pixelPoint = PixelPoint(px, py)
                if drawingState.drawnPixelsInStroke.contains(pixelPoint) {
                    continue
                }
                drawingState.drawnPixelsInStroke.insert(pixelPoint)

                // Single Source of Truth: TimelineViewModel 사용
                let layerId = layerViewModel.layers[currentLayerIndex].id

                // 픽셀을 변경하기 **전에** 이전 값 저장
                var oldValue: PixelValue = .transparent
                if let pixels = timelineViewModel?.getCurrentFramePixels(layerId: layerId),
                   py >= 0, py < pixels.count, px >= 0, px < pixels[py].count {
                    oldValue = pixels[py][px]
                }
                drawingState.oldStrokePixels.append(PixelChange(x: px, y: py, value: oldValue))

                // Color → PixelValue 변환
                let newValue: PixelValue
                if let c = color, let colorIndex = timelineViewModel?.pixelStateManager.currentPalette.findClosest(c) {
                    newValue = .indexed(colorIndex)
                } else {
                    newValue = .transparent
                }

                // 새로운 값 저장
                drawingState.currentStrokePixels.append(PixelChange(x: px, y: py, value: newValue))

                // 픽셀 변경 - TimelineViewModel을 통해 즉시 timeline 반영
                timelineViewModel?.setPixel(layerId: layerId, x: px, y: py, value: newValue)
            }
        }
    }

    /// 두 점 사이를 보간하여 끊김 없이 그립니다
    private func drawInterpolatedLine(from start: (x: Int, y: Int), to end: (x: Int, y: Int)) {
        // Bresenham's line algorithm for interpolation
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        let sx = start.x < end.x ? 1 : -1
        let sy = start.y < end.y ? 1 : -1
        var err = dx - dy

        var x = start.x
        var y = start.y

        while true {
            drawPixel(x: x, y: y)

            if x == end.x && y == end.y {
                break
            }

            let e2 = 2 * err
            if e2 > -dy {
                err -= dy
                x += sx
            }
            if e2 < dx {
                err += dx
                y += sy
            }
        }
    }
}
