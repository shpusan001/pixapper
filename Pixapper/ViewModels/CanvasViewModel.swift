//
//  CanvasViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

enum DrawingTool {
    case pencil
    case eraser
    case fill
    case eyedropper
    case rectangle
    case circle
    case line
}

class CanvasViewModel: ObservableObject {
    @Published var canvas: PixelCanvas
    @Published var selectedTool: DrawingTool = .pencil
    @Published var primaryColor: Color = .black
    @Published var secondaryColor: Color = .white
    @Published var zoomLevel: Double = 400.0
    @Published var shapePreview: [(x: Int, y: Int, color: Color)] = []

    var layerViewModel: LayerViewModel

    private var shapeStartPoint: (x: Int, y: Int)?
    private var cancellables = Set<AnyCancellable>()

    init(width: Int = 32, height: Int = 32, layerViewModel: LayerViewModel) {
        self.canvas = PixelCanvas(width: width, height: height)
        self.layerViewModel = layerViewModel

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
        switch selectedTool {
        case .pencil, .eraser:
            drawPixel(x: x, y: y)
        case .fill:
            floodFill(x: x, y: y, fillColor: primaryColor)
        case .eyedropper:
            pickColor(x: x, y: y)
        case .rectangle, .circle, .line:
            shapeStartPoint = (x, y)
            updateShapePreview(endX: x, endY: y)
        }
    }

    func handleToolDrag(x: Int, y: Int) {
        switch selectedTool {
        case .pencil, .eraser:
            drawPixel(x: x, y: y)
        case .rectangle, .circle, .line:
            updateShapePreview(endX: x, endY: y)
        default:
            break
        }
    }

    func handleToolUp(x: Int, y: Int) {
        switch selectedTool {
        case .rectangle, .circle, .line:
            commitShape()
            shapeStartPoint = nil
            shapePreview = []
        default:
            break
        }
    }

    private func drawPixel(x: Int, y: Int) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }

        let color: Color?
        switch selectedTool {
        case .pencil:
            color = primaryColor
        case .eraser:
            color = nil
        default:
            return
        }

        layerViewModel.layers[currentLayerIndex].setPixel(x: x, y: y, color: color)
    }

    private func floodFill(x: Int, y: Int, fillColor: Color) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }
        let layer = layerViewModel.layers[currentLayerIndex]
        let targetColor = layer.getPixel(x: x, y: y)

        // Don't fill if target and fill colors are the same
        if colorsEqual(targetColor, fillColor) {
            return
        }

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

            layerViewModel.layers[currentLayerIndex].setPixel(x: px, y: py, color: fillColor)

            stack.append((px + 1, py))
            stack.append((px - 1, py))
            stack.append((px, py + 1))
            stack.append((px, py - 1))
        }
    }

    private func pickColor(x: Int, y: Int) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }
        if let color = layerViewModel.layers[currentLayerIndex].getPixel(x: x, y: y) {
            primaryColor = color
        }
    }

    private func updateShapePreview(endX: Int, endY: Int) {
        guard let start = shapeStartPoint else { return }

        var pixels: [(x: Int, y: Int)] = []

        switch selectedTool {
        case .rectangle:
            pixels = getRectanglePixels(x1: start.x, y1: start.y, x2: endX, y2: endY)
        case .circle:
            pixels = getCirclePixels(centerX: start.x, centerY: start.y, toX: endX, toY: endY)
        case .line:
            pixels = getLinePixels(x1: start.x, y1: start.y, x2: endX, y2: endY)
        default:
            break
        }

        shapePreview = pixels.map { ($0.x, $0.y, primaryColor) }
    }

    private func commitShape() {
        guard currentLayerIndex < layerViewModel.layers.count else { return }

        for pixel in shapePreview {
            layerViewModel.layers[currentLayerIndex].setPixel(x: pixel.x, y: pixel.y, color: pixel.color)
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

    private func colorsEqual(_ c1: Color?, _ c2: Color?) -> Bool {
        if c1 == nil && c2 == nil {
            return true
        }
        guard let c1 = c1, let c2 = c2 else {
            return false
        }
        // Simple comparison - in production you'd want to compare RGB values
        return c1 == c2
    }

    func swapColors() {
        let temp = primaryColor
        primaryColor = secondaryColor
        secondaryColor = temp
    }
}
