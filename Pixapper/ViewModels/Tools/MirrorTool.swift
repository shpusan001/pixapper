//
//  MirrorTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI

/// 대칭 그리기 도구
@MainActor
class MirrorTool: BaseTool, CanvasTool {
    // Drawing state
    private var lastDrawPoint: (x: Int, y: Int)?
    private var currentStrokePixels: [PixelChange] = []
    private var oldStrokePixels: [PixelChange] = []
    private var drawnPixelsInStroke: Set<String> = []

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        lastDrawPoint = (x, y)
        currentStrokePixels = []
        oldStrokePixels = []
        drawnPixelsInStroke = []
        drawWithMirror(x: x, y: y)
    }

    func handleDrag(x: Int, y: Int) {
        // 드래그 중에도 프리뷰 위치 업데이트
        canvasViewModel?.brushPreviewPosition = (x, y)

        if let last = lastDrawPoint {
            drawInterpolatedLine(from: last, to: (x, y))
        } else {
            drawWithMirror(x: x, y: y)
        }
        lastDrawPoint = (x, y)
    }

    func handleUp(x: Int, y: Int) {
        if !currentStrokePixels.isEmpty, let layerId = currentLayerId {
            let command = DrawCommand(
                timelineViewModel: timelineViewModel,
                layerId: layerId,
                oldPixels: oldStrokePixels,
                newPixels: currentStrokePixels
            )
            commandManager.addExecutedCommand(command)
        }
        currentStrokePixels = []
        oldStrokePixels = []
        drawnPixelsInStroke = []
        lastDrawPoint = nil
        timelineViewModel?.pixelStateManager?.syncToTimeline()
    }

    func updateHover(x: Int, y: Int) {
        let settings = toolSettingsManager.selectedTool == .mirror ?
            (toolSettingsManager.getSettings(for: .mirror) as? MirrorSettings) : nil

        guard let settings = settings,
              let canvas = canvasViewModel else { return }

        let mode = settings.mode
        let axisPos = settings.axisPosition

        var positions: [(x: Int, y: Int)] = [(x, y)]  // 원본 위치

        // 미러링된 위치들 추가
        switch mode {
        case .horizontal:
            let mirrorX = getMirrorX(x: x, canvasWidth: canvas.canvas.width, axisPos: axisPos)
            positions.append((mirrorX, y))

        case .vertical:
            let mirrorY = getMirrorY(y: y, canvasHeight: canvas.canvas.height, axisPos: axisPos)
            positions.append((x, mirrorY))

        case .both:
            let mirrorX = getMirrorX(x: x, canvasWidth: canvas.canvas.width, axisPos: axisPos)
            let mirrorY = getMirrorY(y: y, canvasHeight: canvas.canvas.height, axisPos: axisPos)
            positions.append((mirrorX, y))
            positions.append((x, mirrorY))
            positions.append((mirrorX, mirrorY))
        }

        canvas.brushPreviewPositions = positions
    }

    func clearHover() {
        canvasViewModel?.brushPreviewPositions = []
    }

    // MARK: - Private Methods

    private func drawWithMirror(x: Int, y: Int) {
        let settings = toolSettingsManager.selectedTool == .mirror ?
            (toolSettingsManager.getSettings(for: .mirror) as? MirrorSettings) : nil

        guard let settings = settings,
              let canvas = canvasViewModel,
              let layerId = currentLayerId else { return }

        let mode = settings.mode
        let axisPos = settings.axisPosition
        let color = settings.color
        let brushSize = settings.brushSize

        // 원본 위치 그리기
        drawPixel(at: (x, y), color: color, brushSize: brushSize, layerId: layerId)

        // 대칭 위치 계산 및 그리기
        switch mode {
        case .horizontal:
            let mirrorX = getMirrorX(x: x, canvasWidth: canvas.canvas.width, axisPos: axisPos)
            drawPixel(at: (mirrorX, y), color: color, brushSize: brushSize, layerId: layerId)

        case .vertical:
            let mirrorY = getMirrorY(y: y, canvasHeight: canvas.canvas.height, axisPos: axisPos)
            drawPixel(at: (x, mirrorY), color: color, brushSize: brushSize, layerId: layerId)

        case .both:
            let mirrorX = getMirrorX(x: x, canvasWidth: canvas.canvas.width, axisPos: axisPos)
            let mirrorY = getMirrorY(y: y, canvasHeight: canvas.canvas.height, axisPos: axisPos)
            drawPixel(at: (mirrorX, y), color: color, brushSize: brushSize, layerId: layerId)
            drawPixel(at: (x, mirrorY), color: color, brushSize: brushSize, layerId: layerId)
            drawPixel(at: (mirrorX, mirrorY), color: color, brushSize: brushSize, layerId: layerId)
        }
    }

    private func getMirrorX(x: Int, canvasWidth: Int, axisPos: Double) -> Int {
        let axis = Int(Double(canvasWidth) * axisPos)
        return 2 * axis - x
    }

    private func getMirrorY(y: Int, canvasHeight: Int, axisPos: Double) -> Int {
        let axis = Int(Double(canvasHeight) * axisPos)
        return 2 * axis - y
    }

    private func drawPixel(at point: (x: Int, y: Int), color: Color, brushSize: Int, layerId: UUID) {
        guard let canvas = canvasViewModel else { return }

        let radius = brushSize / 2
        for dy in -radius...radius {
            for dx in -radius...radius {
                let px = point.x + dx
                let py = point.y + dy

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

                let pixelKey = "\(px),\(py)"
                if drawnPixelsInStroke.contains(pixelKey) {
                    continue
                }
                drawnPixelsInStroke.insert(pixelKey)

                var oldColor: Color? = nil
                if let pixels = timelineViewModel?.getCurrentFramePixels(layerId: layerId),
                   py >= 0, py < pixels.count, px >= 0, px < pixels[py].count {
                    oldColor = pixels[py][px]
                }
                oldStrokePixels.append(PixelChange(x: px, y: py, color: oldColor))
                currentStrokePixels.append(PixelChange(x: px, y: py, color: color))
                timelineViewModel?.setPixel(layerId: layerId, x: px, y: py, color: color)
            }
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
            drawWithMirror(x: x, y: y)

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
