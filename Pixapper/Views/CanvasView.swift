//
//  CanvasView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    var timelineViewModel: TimelineViewModel?
    @State private var isDragging = false

    var body: some View {
        canvasContent
            .background(Color(nsColor: .controlBackgroundColor))
    }

    private var canvasContent: some View {
        let pixelSize = viewModel.zoomLevel / 100.0
        let canvasWidth = CGFloat(viewModel.canvas.width) * pixelSize
        let canvasHeight = CGFloat(viewModel.canvas.height) * pixelSize

        return ScrollView([.horizontal, .vertical]) {
            canvasLayers(pixelSize: pixelSize)
                .frame(width: canvasWidth, height: canvasHeight)
                .gesture(canvasDragGesture(pixelSize: pixelSize))
        }
    }

    @ViewBuilder
    private func canvasLayers(pixelSize: CGFloat) -> some View {
        ZStack {
            // Checkerboard background
            CheckerboardView(
                width: viewModel.canvas.width,
                height: viewModel.canvas.height,
                pixelSize: pixelSize
            )

            // Render onion skin frames
            onionSkinLayers(pixelSize: pixelSize)

            // Render all visible layers (current frame)
            currentFrameLayers(pixelSize: pixelSize)

            // Grid lines
            GridLinesView(
                width: viewModel.canvas.width,
                height: viewModel.canvas.height,
                pixelSize: pixelSize
            )

            // Shape preview overlay
            if !viewModel.shapePreview.isEmpty {
                ShapePreviewView(
                    preview: viewModel.shapePreview,
                    pixelSize: pixelSize
                )
            }
        }
    }

    @ViewBuilder
    private func onionSkinLayers(pixelSize: CGFloat) -> some View {
        if let timeline = timelineViewModel {
            ForEach(timeline.getOnionSkinFrames(), id: \.frameIndex) { onionFrame in
                ForEach(timeline.layerViewModel.layers.indices.reversed(), id: \.self) { layerIndex in
                    let layer = timeline.layerViewModel.layers[layerIndex]
                    if layer.isVisible,
                       let pixels = timeline.getEffectivePixels(frameIndex: onionFrame.frameIndex, layerId: layer.id) {
                        OnionSkinLayerView(
                            layer: Layer(name: layer.name, pixels: pixels),
                            pixelSize: pixelSize,
                            tint: onionFrame.tint,
                            opacity: onionFrame.opacity
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func currentFrameLayers(pixelSize: CGFloat) -> some View {
        ForEach(viewModel.canvas.layers.indices.reversed(), id: \.self) { layerIndex in
            let layer = viewModel.canvas.layers[layerIndex]
            if layer.isVisible {
                PixelGridView(
                    layer: layer,
                    pixelSize: pixelSize
                )
                .opacity(layer.opacity)
            }
        }
    }

    private func canvasDragGesture(pixelSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    handleDown(at: value.startLocation, pixelSize: pixelSize)
                    isDragging = true
                }
                handleDrag(at: value.location, pixelSize: pixelSize)
            }
            .onEnded { value in
                handleUp(at: value.location, pixelSize: pixelSize)
                isDragging = false
            }
    }

    private func handleDown(at location: CGPoint, pixelSize: CGFloat) {
        let x = Int(location.x / pixelSize)
        let y = Int(location.y / pixelSize)

        if x >= 0 && x < viewModel.canvas.width && y >= 0 && y < viewModel.canvas.height {
            viewModel.handleToolDown(x: x, y: y)
        }
    }

    private func handleDrag(at location: CGPoint, pixelSize: CGFloat) {
        let x = Int(location.x / pixelSize)
        let y = Int(location.y / pixelSize)

        if x >= 0 && x < viewModel.canvas.width && y >= 0 && y < viewModel.canvas.height {
            viewModel.handleToolDrag(x: x, y: y)
        }
    }

    private func handleUp(at location: CGPoint, pixelSize: CGFloat) {
        let x = Int(location.x / pixelSize)
        let y = Int(location.y / pixelSize)

        if x >= 0 && x < viewModel.canvas.width && y >= 0 && y < viewModel.canvas.height {
            viewModel.handleToolUp(x: x, y: y)
        }
    }
}

struct CheckerboardView: View {
    let width: Int
    let height: Int
    let pixelSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let lightGray = Color(white: Constants.Canvas.checkerboardLightGray)
            let darkGray = Color(white: Constants.Canvas.checkerboardDarkGray)

            for y in 0..<height {
                for x in 0..<width {
                    let isEven = (x + y) % 2 == 0
                    let rect = CGRect(
                        x: CGFloat(x) * pixelSize,
                        y: CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(
                        Path(rect),
                        with: .color(isEven ? lightGray : darkGray)
                    )
                }
            }
        }
    }
}

struct PixelGridView: View {
    let layer: Layer
    let pixelSize: CGFloat

    var body: some View {
        Canvas { context, size in
            for y in 0..<layer.pixels.count {
                for x in 0..<layer.pixels[y].count {
                    if let color = layer.pixels[y][x] {
                        let rect = CGRect(
                            x: CGFloat(x) * pixelSize,
                            y: CGFloat(y) * pixelSize,
                            width: pixelSize,
                            height: pixelSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}

struct GridLinesView: View {
    let width: Int
    let height: Int
    let pixelSize: CGFloat

    var body: some View {
        Canvas { context, size in
            let gridColor = Color(white: 0.6, opacity: 0.3)
            var path = Path()

            // Vertical lines
            for x in 0...width {
                let xPos = CGFloat(x) * pixelSize
                path.move(to: CGPoint(x: xPos, y: 0))
                path.addLine(to: CGPoint(x: xPos, y: CGFloat(height) * pixelSize))
            }

            // Horizontal lines
            for y in 0...height {
                let yPos = CGFloat(y) * pixelSize
                path.move(to: CGPoint(x: 0, y: yPos))
                path.addLine(to: CGPoint(x: CGFloat(width) * pixelSize, y: yPos))
            }

            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }
}

struct ShapePreviewView: View {
    let preview: [(x: Int, y: Int, color: Color)]
    let pixelSize: CGFloat

    var body: some View {
        Canvas { context, size in
            for pixel in preview {
                let rect = CGRect(
                    x: CGFloat(pixel.x) * pixelSize,
                    y: CGFloat(pixel.y) * pixelSize,
                    width: pixelSize,
                    height: pixelSize
                )
                context.fill(Path(rect), with: .color(pixel.color.opacity(Constants.Opacity.Canvas.shapePreview)))
            }
        }
    }
}

struct OnionSkinLayerView: View {
    let layer: Layer
    let pixelSize: CGFloat
    let tint: Color
    let opacity: Double

    var body: some View {
        Canvas { context, size in
            for y in 0..<layer.pixels.count {
                for x in 0..<layer.pixels[y].count {
                    if let color = layer.pixels[y][x] {
                        let rect = CGRect(
                            x: CGFloat(x) * pixelSize,
                            y: CGFloat(y) * pixelSize,
                            width: pixelSize,
                            height: pixelSize
                        )
                        // Apply tint by blending with the tint color
                        let tintedColor = color.opacity(opacity)
                        context.fill(Path(rect), with: .color(tintedColor))
                        // Add tint overlay
                        context.fill(Path(rect), with: .color(tint.opacity(opacity * 0.3)))
                    }
                }
            }
        }
    }
}
