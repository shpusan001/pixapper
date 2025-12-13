//
//  PencilEraserTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 그리기 도구 (연필, 지우개)
@MainActor
class PencilEraserTool: CanvasTool {
    private weak var canvasViewModel: CanvasViewModel?
    private let layerViewModel: LayerViewModel
    private let commandManager: CommandManager
    private let toolSettingsManager: ToolSettingsManager
    private weak var timelineViewModel: TimelineViewModel?

    // Drawing state
    private var lastDrawPoint: (x: Int, y: Int)?
    private var currentStrokePixels: [PixelChange] = []
    private var oldStrokePixels: [PixelChange] = []
    private var drawnPixelsInStroke: Set<String> = []  // "x,y" 형식으로 저장

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
        guard let canvas = canvasViewModel else { return }
        canvas.brushPreviewPosition = nil  // 그리기 시작 시 미리보기 제거
        lastDrawPoint = (x, y)
        currentStrokePixels = []
        oldStrokePixels = []
        drawnPixelsInStroke = []
        drawPixel(x: x, y: y)
    }

    func handleDrag(x: Int, y: Int) {
        // 보간을 통해 끊김 방지
        if let last = lastDrawPoint {
            drawInterpolatedLine(from: last, to: (x, y))
        } else {
            drawPixel(x: x, y: y)
        }
        lastDrawPoint = (x, y)
    }

    func handleUp(x: Int, y: Int) {
        // 스트로크 완료 - Command 생성
        if !currentStrokePixels.isEmpty {
            let command = DrawCommand(
                layerViewModel: layerViewModel,
                layerIndex: currentLayerIndex,
                oldPixels: oldStrokePixels,
                newPixels: currentStrokePixels
            )
            commandManager.addExecutedCommand(command)
        }
        currentStrokePixels = []
        oldStrokePixels = []
        drawnPixelsInStroke = []
        lastDrawPoint = nil

        // Timeline에 동기화
        timelineViewModel?.syncCurrentLayerToKeyframe()
    }

    func updateHover(x: Int, y: Int) {
        canvasViewModel?.brushPreviewPosition = (x, y)
    }

    func clearHover() {
        canvasViewModel?.brushPreviewPosition = nil
    }

    // MARK: - Private Methods

    private var currentLayerIndex: Int {
        layerViewModel.selectedLayerIndex
    }

    private func drawPixel(x: Int, y: Int) {
        guard let canvas = canvasViewModel,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let color: Color?
        let brushSize: Int

        switch toolSettingsManager.selectedTool {
        case .pencil:
            color = toolSettingsManager.pencilSettings.color
            brushSize = toolSettingsManager.pencilSettings.brushSize
        case .eraser:
            color = nil
            brushSize = toolSettingsManager.eraserSettings.brushSize
        default:
            return
        }

        // 브러시 크기에 따라 여러 픽셀 그리기
        let radius = (brushSize - 1) / 2
        for dy in -radius...radius {
            for dx in -radius...radius {
                let px = x + dx
                let py = y + dy

                // 캔버스 범위 체크
                guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else { continue }

                // 이미 그린 픽셀인지 체크 (보간 중 중복 방지)
                let pixelKey = "\(px),\(py)"
                if drawnPixelsInStroke.contains(pixelKey) {
                    continue
                }
                drawnPixelsInStroke.insert(pixelKey)

                // 픽셀을 변경하기 **전에** 이전 값 저장
                let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: px, y: py)
                oldStrokePixels.append(PixelChange(x: px, y: py, color: oldColor))

                // 새로운 값 저장
                currentStrokePixels.append(PixelChange(x: px, y: py, color: color))

                // 픽셀 변경
                layerViewModel.layers[currentLayerIndex].setPixel(x: px, y: py, color: color)
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
