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
    @State private var eventMonitor: Any?

    var body: some View {
        canvasContent
            .background(Color(nsColor: .controlBackgroundColor))
            .onAppear {
                // Shift 키 모니터링
                eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    viewModel.shiftPressed = event.modifierFlags.contains(.shift)
                    return event
                }
            }
            .onDisappear {
                if let monitor = eventMonitor {
                    NSEvent.removeMonitor(monitor)
                }
            }
    }

    private var canvasContent: some View {
        let pixelSize = viewModel.zoomLevel / 100.0
        let canvasWidth = CGFloat(viewModel.canvas.width) * pixelSize
        let canvasHeight = CGFloat(viewModel.canvas.height) * pixelSize

        // 확장된 전체 영역 (전부 캔버스)
        let margin = max(canvasWidth, canvasHeight)
        let totalWidth = canvasWidth + margin * 2
        let totalHeight = canvasHeight + margin * 2

        // 실제 그림이 보이는 영역의 시작점 (픽셀 좌표)
        let visibleStartX = Int(margin / pixelSize)
        let visibleStartY = Int(margin / pixelSize)

        return ScrollView([.horizontal, .vertical]) {
            // 전체가 하나의 큰 캔버스
            ZStack(alignment: .topLeading) {
                // 배경 (전체 영역)
                Color.clear
                    .frame(width: totalWidth, height: totalHeight)

                // 실제 그림 영역 (중앙)
                canvasLayers(pixelSize: pixelSize)
                    .frame(width: canvasWidth, height: canvasHeight)
                    .offset(x: margin, y: margin)

                // Selection overlay (같은 좌표계, 실제 캔버스 기준점에서 offset)
                if let selectionRect = viewModel.selectionRect {
                    SelectionRectView(
                        rect: selectionRect,
                        offset: viewModel.selectionOffset,
                        pixelSize: pixelSize,
                        selectionPixels: viewModel.selectionPixels,
                        isMoving: viewModel.isMovingSelection,
                        originalPixels: viewModel.originalPixels,
                        originalRect: viewModel.originalRect,
                        selectionMode: viewModel.selectionMode,
                        hoveredHandle: viewModel.hoveredHandle
                    )
                    .offset(x: margin, y: margin)
                }
            }
            .gesture(canvasDragGesture(pixelSize: pixelSize))
            .onContinuousHover { phase in
                handleHover(phase: phase, pixelSize: pixelSize)
            }
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
                    let isAltPressed = NSEvent.modifierFlags.contains(.option)
                    handleDown(at: value.startLocation, pixelSize: pixelSize, altPressed: isAltPressed)
                    isDragging = true
                }
                handleDrag(at: value.location, pixelSize: pixelSize)
            }
            .onEnded { value in
                handleUp(at: value.location, pixelSize: pixelSize)
                isDragging = false
            }
    }

    private func handleDown(at location: CGPoint, pixelSize: CGFloat, altPressed: Bool = false) {
        // 단일 좌표계: 화면 좌표 → 픽셀 좌표 (margin 고려)
        let canvasWidth = CGFloat(viewModel.canvas.width) * pixelSize
        let canvasHeight = CGFloat(viewModel.canvas.height) * pixelSize
        let margin = max(canvasWidth, canvasHeight)

        let x = Int((location.x - margin) / pixelSize)
        let y = Int((location.y - margin) / pixelSize)

        // 선택 도구이고 핸들 위에 있으면 캔버스 밖에서도 동작
        if viewModel.toolSettingsManager.selectedTool == .selection {
            viewModel.updateHover(x: x, y: y)
            if viewModel.hoveredHandle != nil || viewModel.checkInsideSelection(x: x, y: y) {
                viewModel.handleToolDown(x: x, y: y, altPressed: altPressed)
                return
            }
        }

        if x >= 0 && x < viewModel.canvas.width && y >= 0 && y < viewModel.canvas.height {
            viewModel.handleToolDown(x: x, y: y, altPressed: altPressed)
        } else {
            // 캔버스 바깥 클릭 시 선택 취소
            viewModel.handleOutsideClick()
        }
    }

    private func handleDrag(at location: CGPoint, pixelSize: CGFloat) {
        let canvasWidth = CGFloat(viewModel.canvas.width) * pixelSize
        let canvasHeight = CGFloat(viewModel.canvas.height) * pixelSize
        let margin = max(canvasWidth, canvasHeight)

        let x = Int((location.x - margin) / pixelSize)
        let y = Int((location.y - margin) / pixelSize)

        // 선택 도구이고 선택 모드가 활성화되어 있으면 캔버스 밖에서도 동작
        if viewModel.toolSettingsManager.selectedTool == .selection && viewModel.selectionMode != .idle {
            viewModel.handleToolDrag(x: x, y: y)
            return
        }

        // 캔버스 범위로 clamp (밖으로 나가도 계속 동작)
        let clampedX = max(0, min(x, viewModel.canvas.width - 1))
        let clampedY = max(0, min(y, viewModel.canvas.height - 1))

        viewModel.handleToolDrag(x: clampedX, y: clampedY)
    }

    private func handleUp(at location: CGPoint, pixelSize: CGFloat) {
        let canvasWidth = CGFloat(viewModel.canvas.width) * pixelSize
        let canvasHeight = CGFloat(viewModel.canvas.height) * pixelSize
        let margin = max(canvasWidth, canvasHeight)

        let x = Int((location.x - margin) / pixelSize)
        let y = Int((location.y - margin) / pixelSize)

        // 선택 도구이고 선택 모드가 활성화되어 있으면 캔버스 밖에서도 동작
        if viewModel.toolSettingsManager.selectedTool == .selection && viewModel.selectionMode != .idle {
            viewModel.handleToolUp(x: x, y: y)
            return
        }

        // 캔버스 범위로 clamp (밖에서 놓아도 계속 동작)
        let clampedX = max(0, min(x, viewModel.canvas.width - 1))
        let clampedY = max(0, min(y, viewModel.canvas.height - 1))

        viewModel.handleToolUp(x: clampedX, y: clampedY)
    }

    private func handleHover(phase: HoverPhase, pixelSize: CGFloat) {
        switch phase {
        case .active(let location):
            let canvasWidth = CGFloat(viewModel.canvas.width) * pixelSize
            let canvasHeight = CGFloat(viewModel.canvas.height) * pixelSize
            let margin = max(canvasWidth, canvasHeight)

            let x = Int((location.x - margin) / pixelSize)
            let y = Int((location.y - margin) / pixelSize)

            // 선택 도구일 때는 캔버스 밖에서도 호버 업데이트
            if viewModel.toolSettingsManager.selectedTool == .selection {
                viewModel.updateHover(x: x, y: y)
                updateCursor(x: x, y: y)
            } else if x >= 0 && x < viewModel.canvas.width && y >= 0 && y < viewModel.canvas.height {
                // 다른 도구는 캔버스 안에서만
                viewModel.updateHover(x: x, y: y)
                updateCursor(x: x, y: y)
            }
        case .ended:
            // 마우스가 캔버스를 벗어나면 호버 제거
            viewModel.clearHover()
            NSCursor.arrow.set()
        }
    }

    private func updateCursor(x: Int, y: Int) {
        // 선택 도구가 아니면 crosshair
        guard viewModel.toolSettingsManager.selectedTool == .selection else {
            NSCursor.crosshair.set()
            return
        }

        // 핸들 위에 있으면 resize cursor
        if let handle = viewModel.hoveredHandle {
            switch handle {
            case .topLeft, .bottomRight:
                // 대각선 커서는 crosshair로 대체
                NSCursor.crosshair.set()
            case .topRight, .bottomLeft:
                // 대각선 커서는 crosshair로 대체
                NSCursor.crosshair.set()
            case .top, .bottom:
                NSCursor.resizeUpDown.set()
            case .left, .right:
                NSCursor.resizeLeftRight.set()
            case .rotate:
                // 회전 커서 (SF Symbol 사용)
                if let image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Rotate"),
                   let tinted = image.withSymbolConfiguration(.init(pointSize: 16, weight: .regular)) {
                    let cursor = NSCursor(image: tinted, hotSpot: NSPoint(x: 8, y: 8))
                    cursor.set()
                } else {
                    NSCursor.crosshair.set()
                }
            }
            return
        }

        // 선택 영역 내부면 move cursor
        if viewModel.checkInsideSelection(x: x, y: y) {
            NSCursor.openHand.set()
            return
        }

        // 일반 영역은 crosshair
        NSCursor.crosshair.set()
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

struct SelectionRectView: View {
    let rect: CGRect
    let offset: CGPoint
    let pixelSize: CGFloat
    let selectionPixels: [[Color?]]?
    let isMoving: Bool
    let originalPixels: [[Color?]]?
    let originalRect: CGRect?
    let selectionMode: CanvasViewModel.SelectionMode
    let hoveredHandle: CanvasViewModel.ResizeHandle?

    var body: some View {
        Canvas { context, size in
            let effectiveRect = CGRect(
                x: rect.minX + offset.x,
                y: rect.minY + offset.y,
                width: rect.width,
                height: rect.height
            )

            // 이동 중이거나 크기 조절 중이면 원본 잔상 표시
            var showGhost = isMoving
            if case .resizing = selectionMode {
                showGhost = true
            }

            if showGhost,
               let origPixels = originalPixels,
               let origRect = originalRect {
                for y in 0..<origPixels.count {
                    for x in 0..<origPixels[y].count {
                        if let color = origPixels[y][x] {
                            let pixelRect = CGRect(
                                x: (origRect.minX + CGFloat(x)) * pixelSize,
                                y: (origRect.minY + CGFloat(y)) * pixelSize,
                                width: pixelSize,
                                height: pixelSize
                            )
                            // 원본은 반투명하게 (30%)
                            context.fill(Path(pixelRect), with: .color(color.opacity(0.3)))
                        }
                    }
                }
            }

            // Draw the selected pixels at current position
            if let pixels = selectionPixels {
                for y in 0..<pixels.count {
                    for x in 0..<pixels[y].count {
                        if let color = pixels[y][x] {
                            let pixelRect = CGRect(
                                x: (effectiveRect.minX + CGFloat(x)) * pixelSize,
                                y: (effectiveRect.minY + CGFloat(y)) * pixelSize,
                                width: pixelSize,
                                height: pixelSize
                            )
                            // 이동/크기조절 중일 때는 연하게 (미리보기 효과)
                            var opacity = 1.0
                            if isMoving {
                                opacity = 0.6
                            } else if case .resizing = selectionMode {
                                opacity = 0.6
                            }
                            context.fill(Path(pixelRect), with: .color(color.opacity(opacity)))
                        }
                    }
                }
            }

            // Draw selection rectangle border
            let borderRect = CGRect(
                x: effectiveRect.minX * pixelSize,
                y: effectiveRect.minY * pixelSize,
                width: effectiveRect.width * pixelSize,
                height: effectiveRect.height * pixelSize
            )

            // Draw dashed border (더 선명하고 진하게)
            var path = Path()
            path.addRect(borderRect)
            context.stroke(
                path,
                with: .color(Color(red: 0.0, green: 0.5, blue: 1.0)),  // 밝은 파란색
                style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
            )

            // Draw resize handles (9 handles including rotate) - 크기 증가 및 시각적 개선
            let baseHandleSize: CGFloat = 11
            let handleTypes: [CanvasViewModel.ResizeHandle] = [
                .topLeft, .topRight, .bottomLeft, .bottomRight,
                .top, .bottom, .left, .right, .rotate
            ]
            let handlePositions: [(x: CGFloat, y: CGFloat)] = [
                // Corners
                (borderRect.minX, borderRect.minY),        // top-left
                (borderRect.maxX, borderRect.minY),        // top-right
                (borderRect.minX, borderRect.maxY),        // bottom-left
                (borderRect.maxX, borderRect.maxY),        // bottom-right
                // Edges
                (borderRect.midX, borderRect.minY),        // top
                (borderRect.midX, borderRect.maxY),        // bottom
                (borderRect.minX, borderRect.midY),        // left
                (borderRect.maxX, borderRect.midY),        // right
                // Rotate handle (위쪽 중앙에서 3픽셀 위)
                (borderRect.midX, borderRect.minY - 3 * pixelSize)
            ]

            for (index, position) in handlePositions.enumerated() {
                let handleType = handleTypes[index]
                let isHovered = hoveredHandle == handleType

                // 호버 시 핸들 크기 증가
                let handleSize = isHovered ? baseHandleSize * 1.3 : baseHandleSize

                // 회전 핸들은 원형으로 표시
                if handleType == .rotate {
                    let circleRect = CGRect(
                        x: position.x - handleSize / 2,
                        y: position.y - handleSize / 2,
                        width: handleSize,
                        height: handleSize
                    )

                    // 선으로 연결 (위쪽 중앙과 회전 핸들)
                    var linePath = Path()
                    linePath.move(to: CGPoint(x: borderRect.midX, y: borderRect.minY))
                    linePath.addLine(to: CGPoint(x: position.x, y: position.y))
                    context.stroke(
                        linePath,
                        with: .color(Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.5)),
                        lineWidth: 1.5
                    )

                    // 원형 핸들
                    let circlePath = Path(ellipseIn: circleRect)
                    let fillColor: Color = isHovered ? Color(red: 0.4, green: 0.7, blue: 1.0, opacity: 0.7) : Color(red: 0.0, green: 0.5, blue: 1.0, opacity: 0.9)
                    let borderColor: Color = .white
                    let borderWidth: CGFloat = 2

                    context.fill(circlePath, with: .color(fillColor))
                    context.stroke(circlePath, with: .color(borderColor), lineWidth: borderWidth)
                } else {
                    // 일반 핸들은 사각형
                    let handleRect = CGRect(
                        x: position.x - handleSize / 2,
                        y: position.y - handleSize / 2,
                        width: handleSize,
                        height: handleSize
                    )

                    // 그림자 효과 (깊이감 추가)
                    let shadowPath = Path(handleRect)
                    context.fill(
                        shadowPath,
                        with: .color(.black.opacity(0.15))
                    )

                    // Fill color: white or bright blue if hovered
                    let fillColor: Color = isHovered ? Color(red: 0.4, green: 0.7, blue: 1.0, opacity: 0.5) : .white
                    // Border color: bright blue
                    let borderColor: Color = isHovered ? Color(red: 0.0, green: 0.5, blue: 1.0) : Color(red: 0.0, green: 0.45, blue: 0.9)
                    let borderWidth: CGFloat = isHovered ? 2.5 : 2

                    context.fill(Path(handleRect), with: .color(fillColor))
                    context.stroke(Path(handleRect), with: .color(borderColor), lineWidth: borderWidth)
                }
            }
        }
    }
}
