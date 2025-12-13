//
//  ShapeTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 도형 도구 (사각형, 원, 선)
@MainActor
class ShapeTool: CanvasTool {
    private weak var canvasViewModel: CanvasViewModel?
    private let layerViewModel: LayerViewModel
    private let commandManager: CommandManager
    private let toolSettingsManager: ToolSettingsManager
    private weak var timelineViewModel: TimelineViewModel?

    // Shape state
    private var shapeStartPoint: (x: Int, y: Int)?

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
        shapeStartPoint = (x, y)
        updateShapePreview(endX: x, endY: y)
    }

    func handleDrag(x: Int, y: Int) {
        updateShapePreview(endX: x, endY: y)
    }

    func handleUp(x: Int, y: Int) {
        commitShape()
        shapeStartPoint = nil
        canvasViewModel?.shapePreview = []

        // Timeline에 동기화
        timelineViewModel?.syncCurrentLayerToKeyframe()
    }

    // MARK: - Private Methods

    private var currentLayerIndex: Int {
        layerViewModel.selectedLayerIndex
    }

    private func updateShapePreview(endX: Int, endY: Int) {
        guard let canvas = canvasViewModel,
              let start = shapeStartPoint else { return }

        var pixels: [(x: Int, y: Int, Color)] = []

        switch toolSettingsManager.selectedTool {
        case .rectangle:
            let settings = toolSettingsManager.rectangleSettings
            pixels = getRectanglePixels(
                x1: start.x, y1: start.y, x2: endX, y2: endY,
                strokeWidth: settings.strokeWidth,
                strokeColor: settings.strokeColor,
                fillColor: settings.fillColor
            )
        case .circle:
            let settings = toolSettingsManager.circleSettings
            pixels = getCirclePixels(
                centerX: start.x, centerY: start.y, toX: endX, toY: endY,
                strokeWidth: settings.strokeWidth,
                strokeColor: settings.strokeColor,
                fillColor: settings.fillColor
            )
        case .line:
            let settings = toolSettingsManager.lineSettings
            pixels = getLinePixels(
                x1: start.x, y1: start.y, x2: endX, y2: endY,
                strokeWidth: settings.strokeWidth,
                strokeColor: settings.strokeColor
            )
        default:
            break
        }

        canvas.shapePreview = pixels
    }

    private func commitShape() {
        guard let canvas = canvasViewModel,
              currentLayerIndex < layerViewModel.layers.count else { return }

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        for pixel in canvas.shapePreview {
            let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: pixel.x, y: pixel.y)
            oldPixels.append(PixelChange(x: pixel.x, y: pixel.y, color: oldColor))
            newPixels.append(PixelChange(x: pixel.x, y: pixel.y, color: pixel.color))

            layerViewModel.layers[currentLayerIndex].setPixel(x: pixel.x, y: pixel.y, color: pixel.color)
        }

        // Command 생성 (이미 실행된 상태)
        if !newPixels.isEmpty {
            let command = DrawCommand(
                layerViewModel: layerViewModel,
                layerIndex: currentLayerIndex,
                oldPixels: oldPixels,
                newPixels: newPixels
            )
            commandManager.addExecutedCommand(command)
        }
    }

    // MARK: - Shape Drawing Algorithms

    private func getRectanglePixels(
        x1: Int, y1: Int, x2: Int, y2: Int,
        strokeWidth: Int, strokeColor: Color, fillColor: Color?
    ) -> [(x: Int, y: Int, Color)] {
        guard let canvas = canvasViewModel else { return [] }

        var pixels: [(x: Int, y: Int, Color)] = []
        let minX = min(x1, x2)
        let maxX = max(x1, x2)
        let minY = min(y1, y2)
        let maxY = max(y1, y2)

        // Fill interior if fillColor is set
        if let fill = fillColor {
            for y in minY...maxY {
                for x in minX...maxX {
                    pixels.append((x, y, fill))
                }
            }
        }

        // Draw stroke (outline) with strokeWidth
        let halfWidth = (strokeWidth - 1) / 2
        for w in 0..<strokeWidth {
            let offset = w - halfWidth

            // Top and bottom edges
            for x in minX...maxX {
                let topY = minY + offset
                let bottomY = maxY + offset
                if topY >= 0 && topY < canvas.canvas.height {
                    pixels.append((x, topY, strokeColor))
                }
                if bottomY >= 0 && bottomY < canvas.canvas.height {
                    pixels.append((x, bottomY, strokeColor))
                }
            }

            // Left and right edges
            for y in minY...maxY {
                let leftX = minX + offset
                let rightX = maxX + offset
                if leftX >= 0 && leftX < canvas.canvas.width {
                    pixels.append((leftX, y, strokeColor))
                }
                if rightX >= 0 && rightX < canvas.canvas.width {
                    pixels.append((rightX, y, strokeColor))
                }
            }
        }

        return pixels
    }

    private func getCirclePixels(
        centerX: Int, centerY: Int, toX: Int, toY: Int,
        strokeWidth: Int, strokeColor: Color, fillColor: Color?
    ) -> [(x: Int, y: Int, Color)] {
        guard let canvas = canvasViewModel else { return [] }

        var pixels: [(x: Int, y: Int, Color)] = []
        let dx = toX - centerX
        let dy = toY - centerY
        let radius = Int(sqrt(Double(dx * dx + dy * dy)))

        // Fill interior if fillColor is set
        if let fill = fillColor {
            for y in (centerY - radius)...(centerY + radius) {
                for x in (centerX - radius)...(centerX + radius) {
                    let distSq = (x - centerX) * (x - centerX) + (y - centerY) * (y - centerY)
                    if distSq <= radius * radius {
                        pixels.append((x, y, fill))
                    }
                }
            }
        }

        // Draw stroke with strokeWidth
        let halfWidth = (strokeWidth - 1) / 2
        for w in 0..<strokeWidth {
            let r = radius + w - halfWidth
            guard r > 0 else { continue }

            // Bresenham's circle algorithm
            var x = 0
            var y = r
            var d = 3 - 2 * r

            func addCirclePoints(_ cx: Int, _ cy: Int, _ x: Int, _ y: Int) {
                let points = [
                    (cx + x, cy + y), (cx - x, cy + y), (cx + x, cy - y), (cx - x, cy - y),
                    (cx + y, cy + x), (cx - y, cy + x), (cx + y, cy - x), (cx - y, cy - x)
                ]
                for point in points {
                    if point.0 >= 0 && point.0 < canvas.canvas.width && point.1 >= 0 && point.1 < canvas.canvas.height {
                        pixels.append((point.0, point.1, strokeColor))
                    }
                }
            }

            addCirclePoints(centerX, centerY, x, y)

            while y >= x {
                x += 1
                if d > 0 {
                    y -= 1
                    d = d + 4 * (x - y) + 10
                } else {
                    d = d + 4 * x + 6
                }
                addCirclePoints(centerX, centerY, x, y)
            }
        }

        return pixels
    }

    private func getLinePixels(
        x1: Int, y1: Int, x2: Int, y2: Int,
        strokeWidth: Int, strokeColor: Color
    ) -> [(x: Int, y: Int, Color)] {
        guard let canvas = canvasViewModel else { return [] }

        var pixels: [(x: Int, y: Int, Color)] = []

        // Get base line pixels using Bresenham's algorithm
        var basePixels: [(x: Int, y: Int)] = []
        let dx = abs(x2 - x1)
        let dy = abs(y2 - y1)
        let sx = x1 < x2 ? 1 : -1
        let sy = y1 < y2 ? 1 : -1
        var err = dx - dy

        var x = x1
        var y = y1

        while true {
            basePixels.append((x, y))

            if x == x2 && y == y2 {
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

        // Apply strokeWidth by drawing around each base pixel
        let halfWidth = (strokeWidth - 1) / 2
        for basePixel in basePixels {
            for dy in -halfWidth...halfWidth {
                for dx in -halfWidth...halfWidth {
                    let px = basePixel.x + dx
                    let py = basePixel.y + dy
                    if px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height {
                        pixels.append((px, py, strokeColor))
                    }
                }
            }
        }

        return pixels
    }
}
