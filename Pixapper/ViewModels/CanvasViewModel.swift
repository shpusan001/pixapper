//
//  CanvasViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

@MainActor
class CanvasViewModel: ObservableObject {
    @Published var canvas: PixelCanvas
    @Published var zoomLevel: Double = 400.0
    @Published var shapePreview: [(x: Int, y: Int, color: Color)] = []

    var layerViewModel: LayerViewModel
    var commandManager: CommandManager
    var toolSettingsManager: ToolSettingsManager
    weak var timelineViewModel: TimelineViewModel?  // Timeline 동기화용

    private var shapeStartPoint: (x: Int, y: Int)?
    private var lastDrawPoint: (x: Int, y: Int)?
    private var currentStrokePixels: [PixelChange] = []
    private var oldStrokePixels: [PixelChange] = []
    private var drawnPixelsInStroke: Set<String> = []  // "x,y" 형식으로 저장
    private var cancellables = Set<AnyCancellable>()

    init(width: Int = 32, height: Int = 32, layerViewModel: LayerViewModel, commandManager: CommandManager, toolSettingsManager: ToolSettingsManager) {
        self.canvas = PixelCanvas(width: width, height: height)
        self.layerViewModel = layerViewModel
        self.commandManager = commandManager
        self.toolSettingsManager = toolSettingsManager

        // Sync canvas layers with LayerViewModel
        layerViewModel.$layers
            .sink { [weak self] layers in
                self?.canvas.layers = layers
            }
            .store(in: &cancellables)
    }

    var currentLayerIndex: Int {
        layerViewModel.selectedLayerIndex
    }

    func handleToolDown(x: Int, y: Int) {
        switch toolSettingsManager.selectedTool {
        case .pencil, .eraser:
            lastDrawPoint = (x, y)
            currentStrokePixels = []
            oldStrokePixels = []
            drawnPixelsInStroke = []
            drawPixel(x: x, y: y)
        case .fill:
            floodFill(x: x, y: y, fillColor: toolSettingsManager.currentColor)
        case .eyedropper:
            pickColor(x: x, y: y)
        case .rectangle, .circle, .line:
            shapeStartPoint = (x, y)
            updateShapePreview(endX: x, endY: y)
        }
    }

    func handleToolDrag(x: Int, y: Int) {
        switch toolSettingsManager.selectedTool {
        case .pencil, .eraser:
            // 보간을 통해 끊김 방지
            if let last = lastDrawPoint {
                drawInterpolatedLine(from: last, to: (x, y))
            } else {
                drawPixel(x: x, y: y)
            }
            lastDrawPoint = (x, y)
        case .rectangle, .circle, .line:
            updateShapePreview(endX: x, endY: y)
        default:
            break
        }
    }

    func handleToolUp(x: Int, y: Int) {
        switch toolSettingsManager.selectedTool {
        case .pencil, .eraser:
            // 스트로크 완료 - Command 생성
            if !currentStrokePixels.isEmpty {
                // 이미 저장해둔 oldStrokePixels 사용
                let command = DrawCommand(layerViewModel: layerViewModel, layerIndex: currentLayerIndex, oldPixels: oldStrokePixels, newPixels: currentStrokePixels)
                // 이미 실행된 상태이므로 히스토리에만 추가
                commandManager.addExecutedCommand(command)
            }
            currentStrokePixels = []
            oldStrokePixels = []
            drawnPixelsInStroke = []
            lastDrawPoint = nil

            // Timeline에 동기화 (키프레임에 저장)
            timelineViewModel?.syncCurrentLayerToKeyframe()

        case .rectangle, .circle, .line:
            commitShape()
            shapeStartPoint = nil
            shapePreview = []

            // Timeline에 동기화 (키프레임에 저장)
            timelineViewModel?.syncCurrentLayerToKeyframe()

        default:
            break
        }
    }

    private func drawPixel(x: Int, y: Int) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }

        let color: Color?
        switch toolSettingsManager.selectedTool {
        case .pencil:
            color = toolSettingsManager.currentColor
        case .eraser:
            color = nil
        default:
            return
        }

        // 이미 그린 픽셀인지 체크 (보간 중 중복 방지)
        let pixelKey = "\(x),\(y)"
        if drawnPixelsInStroke.contains(pixelKey) {
            return
        }
        drawnPixelsInStroke.insert(pixelKey)

        // 픽셀을 변경하기 **전에** 이전 값 저장
        let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: x, y: y)
        oldStrokePixels.append(PixelChange(x: x, y: y, color: oldColor))

        // 새로운 값 저장
        currentStrokePixels.append(PixelChange(x: x, y: y, color: color))

        // 픽셀 변경
        layerViewModel.layers[currentLayerIndex].setPixel(x: x, y: y, color: color)
    }

    /// 두 점 사이를 보간하여 끊김 없이 그립니다
    private func drawInterpolatedLine(from start: (x: Int, y: Int), to end: (x: Int, y: Int)) {
        let pixels = getLinePixels(x1: start.x, y1: start.y, x2: end.x, y2: end.y)
        for pixel in pixels {
            drawPixel(x: pixel.x, y: pixel.y)
        }
    }

    /// 이전 픽셀 값을 가져옵니다 (Undo용)
    private func getOldPixel(x: Int, y: Int) -> Color? {
        guard currentLayerIndex < layerViewModel.layers.count else { return nil }
        return layerViewModel.layers[currentLayerIndex].getPixel(x: x, y: y)
    }

    private func floodFill(x: Int, y: Int, fillColor: Color) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }
        let layer = layerViewModel.layers[currentLayerIndex]
        let targetColor = layer.getPixel(x: x, y: y)

        // Don't fill if target and fill colors are the same
        if colorsEqual(targetColor, fillColor) {
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

            guard px >= 0 && px < canvas.width && py >= 0 && py < canvas.height else {
                continue
            }

            let currentColor = layerViewModel.layers[currentLayerIndex].getPixel(x: px, y: py)
            if !colorsEqual(currentColor, targetColor) {
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
            let command = DrawCommand(layerViewModel: layerViewModel, layerIndex: currentLayerIndex, oldPixels: oldPixels, newPixels: changedPixels)
            commandManager.addExecutedCommand(command)

            // Timeline에 동기화 (키프레임에 저장)
            timelineViewModel?.syncCurrentLayerToKeyframe()
        }
    }

    private func pickColor(x: Int, y: Int) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }
        if let color = layerViewModel.layers[currentLayerIndex].getPixel(x: x, y: y) {
            toolSettingsManager.currentColor = color
        }
    }

    private func updateShapePreview(endX: Int, endY: Int) {
        guard let start = shapeStartPoint else { return }

        var pixels: [(x: Int, y: Int)] = []

        switch toolSettingsManager.selectedTool {
        case .rectangle:
            pixels = getRectanglePixels(x1: start.x, y1: start.y, x2: endX, y2: endY)
        case .circle:
            pixels = getCirclePixels(centerX: start.x, centerY: start.y, toX: endX, toY: endY)
        case .line:
            pixels = getLinePixels(x1: start.x, y1: start.y, x2: endX, y2: endY)
        default:
            break
        }

        shapePreview = pixels.map { ($0.x, $0.y, toolSettingsManager.currentColor) }
    }

    private func commitShape() {
        guard currentLayerIndex < layerViewModel.layers.count else { return }

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        for pixel in shapePreview {
            let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: pixel.x, y: pixel.y)
            oldPixels.append(PixelChange(x: pixel.x, y: pixel.y, color: oldColor))
            newPixels.append(PixelChange(x: pixel.x, y: pixel.y, color: pixel.color))

            layerViewModel.layers[currentLayerIndex].setPixel(x: pixel.x, y: pixel.y, color: pixel.color)
        }

        // Command 생성 (이미 실행된 상태)
        if !newPixels.isEmpty {
            let command = DrawCommand(layerViewModel: layerViewModel, layerIndex: currentLayerIndex, oldPixels: oldPixels, newPixels: newPixels)
            commandManager.addExecutedCommand(command)
        }
    }

    private func getRectanglePixels(x1: Int, y1: Int, x2: Int, y2: Int) -> [(x: Int, y: Int)] {
        var pixels: [(x: Int, y: Int)] = []
        let minX = min(x1, x2)
        let maxX = max(x1, x2)
        let minY = min(y1, y2)
        let maxY = max(y1, y2)

        // Draw outline
        for x in minX...maxX {
            pixels.append((x, minY))
            pixels.append((x, maxY))
        }
        for y in minY...maxY {
            pixels.append((minX, y))
            pixels.append((maxX, y))
        }

        return pixels
    }

    private func getCirclePixels(centerX: Int, centerY: Int, toX: Int, toY: Int) -> [(x: Int, y: Int)] {
        var pixels: [(x: Int, y: Int)] = []
        let dx = toX - centerX
        let dy = toY - centerY
        let radius = Int(sqrt(Double(dx * dx + dy * dy)))

        // Bresenham's circle algorithm
        var x = 0
        var y = radius
        var d = 3 - 2 * radius

        func addCirclePoints(_ cx: Int, _ cy: Int, _ x: Int, _ y: Int) {
            pixels.append((cx + x, cy + y))
            pixels.append((cx - x, cy + y))
            pixels.append((cx + x, cy - y))
            pixels.append((cx - x, cy - y))
            pixels.append((cx + y, cy + x))
            pixels.append((cx - y, cy + x))
            pixels.append((cx + y, cy - x))
            pixels.append((cx - y, cy - x))
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

        return pixels
    }

    private func getLinePixels(x1: Int, y1: Int, x2: Int, y2: Int) -> [(x: Int, y: Int)] {
        var pixels: [(x: Int, y: Int)] = []

        // Bresenham's line algorithm
        let dx = abs(x2 - x1)
        let dy = abs(y2 - y1)
        let sx = x1 < x2 ? 1 : -1
        let sy = y1 < y2 ? 1 : -1
        var err = dx - dy

        var x = x1
        var y = y1

        while true {
            pixels.append((x, y))

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

        return pixels
    }

    /// 두 색상의 RGB 정밀 비교
    /// - Parameters:
    ///   - c1: 첫 번째 색상 (nil 허용)
    ///   - c2: 두 번째 색상 (nil 허용)
    /// - Returns: 두 색상이 동일하면 true
    private func colorsEqual(_ c1: Color?, _ c2: Color?) -> Bool {
        if c1 == nil && c2 == nil {
            return true
        }
        guard let c1 = c1, let c2 = c2 else {
            return false
        }
        // RGB 정밀 비교 (허용 오차 0.001)
        return c1.isEqual(to: c2, tolerance: 0.001)
    }
}
