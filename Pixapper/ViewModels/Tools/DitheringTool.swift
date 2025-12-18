//
//  DitheringTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI

/// 디더링 브러시 도구
@MainActor
class DitheringTool: BaseTool, CanvasTool {
    // Drawing state
    private var lastDrawPoint: (x: Int, y: Int)?

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        lastDrawPoint = (x, y)
        beginStroke()
        drawDithering(x: x, y: y)
    }

    func handleDrag(x: Int, y: Int) {
        // 드래그 중에도 프리뷰 위치 업데이트
        canvasViewModel?.brushPreviewPosition = (x, y)

        if let last = lastDrawPoint {
            drawInterpolatedLine(from: last, to: (x, y))
        } else {
            drawDithering(x: x, y: y)
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

    private func drawDithering(x: Int, y: Int) {
        let settings = toolSettingsManager.selectedTool == .dithering ?
            (toolSettingsManager.getSettings(for: .dithering) as? DitheringSettings) : nil

        guard let settings = settings,
              let canvas = canvasViewModel,
              let layerId = currentLayerId else { return }

        let pattern = settings.pattern
        let color1 = toolSettingsManager.colorManager.primaryColor
        let color2 = toolSettingsManager.colorManager.secondaryColor
        let brushSize = settings.brushSize
        let density = settings.density

        let radius = brushSize / 2
        for dy in -radius...radius {
            for dx in -radius...radius {
                let px = x + dx
                let py = y + dy

                guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else { continue }

                // 브러시 모양 결정
                let isInBrush: Bool
                if brushSize % 2 == 1 {
                    // 홀수: 정사각형
                    isInBrush = true
                } else {
                    // 짝수: 원형 (맨해튼 거리)
                    isInBrush = abs(dx) + abs(dy) <= radius
                }
                guard isInBrush else { continue }

                let pixelPoint = PixelPoint(px, py)
                if drawingState.drawnPixelsInStroke.contains(pixelPoint) {
                    continue
                }
                drawingState.drawnPixelsInStroke.insert(pixelPoint)

                // 패턴에 따라 색상 결정 (항상 그림)
                // shouldDrawPixel은 항상 true를 반환하므로 체크 불필요

                let color = getPatternColor(x: px, y: py, pattern: pattern, color1: color1, color2: color2)

                var oldColor: Color? = nil
                if let pixels = timelineViewModel?.getCurrentFramePixels(layerId: layerId),
                   py >= 0, py < pixels.count, px >= 0, px < pixels[py].count {
                    oldColor = pixels[py][px]
                }
                drawingState.oldStrokePixels.append(PixelChange(x: px, y: py, color: oldColor))
                drawingState.currentStrokePixels.append(PixelChange(x: px, y: py, color: color))
                timelineViewModel?.setPixel(layerId: layerId, x: px, y: py, color: color)
            }
        }
    }

    private func shouldDrawPixel(x: Int, y: Int, pattern: DitheringPattern, density: Double) -> Bool {
        // 모든 패턴은 항상 그림 (색상으로 패턴 구분)
        return true
    }

    private func getPatternColor(x: Int, y: Int, pattern: DitheringPattern, color1: Color, color2: Color) -> Color {
        switch pattern {
        case .checkerboard:
            // 체커보드: 대각선 / 방향
            return (x + y) % 2 == 0 ? color1 : color2

        case .dots:
            // 점 패턴 (25% 밀도)
            return (x % 2 == 0 && y % 2 == 0) ? color1 : color2

        case .horizontal:
            // 수평 줄무늬
            return y % 2 == 0 ? color1 : color2

        case .vertical:
            // 수직 줄무늬
            return x % 2 == 0 ? color1 : color2

        case .crosshatch:
            // 크로스 해치 (격자)
            return (x % 2 == 0 || y % 2 == 0) ? color1 : color2

        case .sparse:
            // 드문 점 패턴 (12.5% 밀도)
            return (x % 4 == 0 && y % 4 == 0) ? color1 : color2

        case .custom:
            // 커스텀 패턴 (동적 크기 타일링)
            let settings = toolSettingsManager.selectedTool == .dithering ?
                (toolSettingsManager.getSettings(for: .dithering) as? DitheringSettings) : nil
            guard let customPattern = settings?.customPattern,
                  let patternSize = settings?.customPatternSize else {
                return color1
            }
            let patternX = ((x % patternSize) + patternSize) % patternSize  // 음수 좌표 처리
            let patternY = ((y % patternSize) + patternSize) % patternSize
            return customPattern[patternY][patternX] ? color1 : color2
        }
    }

    private func drawInterpolatedLine(from start: (x: Int, y: Int), to end: (x: Int, y: Int)) {
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)
        let sx = start.x < end.x ? 1 : -1
        let sy = start.y < end.y ? 1 : -1
        var err = dx - dy

        var x = start.x
        var y = start.y

        while true {
            drawDithering(x: x, y: y)

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
