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
    @State private var dragMonitor: Any?
    @State private var canvasGlobalFrame: CGRect = .zero
    @State private var currentMarginX: CGFloat = 0
    @State private var currentMarginY: CGFloat = 0
    @State private var scrollPosition: CGPoint = .zero

    // MARK: - Computed Properties

    private var pixelSize: CGFloat {
        viewModel.zoomLevel / 100.0
    }

    private var canvasWidth: CGFloat {
        CGFloat(viewModel.canvas.width) * pixelSize
    }

    private var canvasHeight: CGFloat {
        CGFloat(viewModel.canvas.height) * pixelSize
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let viewportWidth = geometry.size.width
            let viewportHeight = geometry.size.height

            // 뷰포트 크기에 따라 동적 마진 (최소한으로)
            let marginX = max(200, (viewportWidth - canvasWidth) / 2)
            let marginY = max(200, (viewportHeight - canvasHeight) / 2)
            let totalWidth = canvasWidth + marginX * 2
            let totalHeight = canvasHeight + marginY * 2

            ScrollViewReader { scrollProxy in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // 전체 배경
                        Color(nsColor: .controlBackgroundColor)

                        // 캔버스 배경 (체커보드 또는 흰색)
                        if viewModel.backgroundMode == .checkerboard {
                            CheckerboardView(
                                width: viewModel.canvas.width,
                                height: viewModel.canvas.height,
                                pixelSize: pixelSize,
                                marginX: marginX,
                                marginY: marginY
                            )
                        } else {
                            // 흰색 배경
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: canvasWidth, height: canvasHeight)
                                .offset(x: marginX, y: marginY)
                        }

                        // 어니언 스킨
                        renderOnionSkinLayers(marginX: marginX, marginY: marginY)

                        // 현재 레이어
                        renderCurrentLayers(marginX: marginX, marginY: marginY)

                        // 격자선 (조건부)
                        if viewModel.showGrid {
                            GridLinesView(
                                width: viewModel.canvas.width,
                                height: viewModel.canvas.height,
                                pixelSize: pixelSize,
                                marginX: marginX,
                                marginY: marginY
                            )
                        }

                        // 도형 프리뷰 (전체 영역)
                        renderShapePreview(marginX: marginX, marginY: marginY)

                        // 선택 영역 (전체 영역)
                        renderSelection(marginX: marginX, marginY: marginY)
                    }
                    .frame(width: totalWidth, height: totalHeight)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                canvasGlobalFrame = geo.frame(in: .global)
                                currentMarginX = marginX
                                currentMarginY = marginY
                            }
                            .onChange(of: geo.frame(in: .global)) { _, newFrame in
                                canvasGlobalFrame = newFrame
                                currentMarginX = marginX
                                currentMarginY = marginY
                            }
                        }
                    )
                    .contentShape(Rectangle())
                    .gesture(dragGesture(marginX: marginX, marginY: marginY))
                    .onContinuousHover { phase in
                        handleHover(phase: phase, marginX: marginX, marginY: marginY)
                    }
                    .id("canvasContent")
                }
                .onAppear {
                    // 초기에 중앙으로 스크롤
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        scrollProxy.scrollTo("canvasContent", anchor: .center)
                    }
                }
            }
        }
        .onAppear(perform: setupEventMonitor)
        .onDisappear {
            cleanupEventMonitor()
            stopDragMonitor()
        }
    }

    // MARK: - Layer Rendering

    @ViewBuilder
    private func renderOnionSkinLayers(marginX: CGFloat, marginY: CGFloat) -> some View {
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
                            opacity: onionFrame.opacity,
                            marginX: marginX,
                            marginY: marginY
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderCurrentLayers(marginX: CGFloat, marginY: CGFloat) -> some View {
        ForEach(viewModel.canvas.layers.indices.reversed(), id: \.self) { index in
            let layer = viewModel.canvas.layers[index]
            if layer.isVisible {
                PixelGridView(layer: layer, pixelSize: pixelSize, marginX: marginX, marginY: marginY)
                    .opacity(layer.opacity)
            }
        }
    }

    @ViewBuilder
    private func renderShapePreview(marginX: CGFloat, marginY: CGFloat) -> some View {
        if !viewModel.shapePreview.isEmpty {
            ShapePreviewView(preview: viewModel.shapePreview, pixelSize: pixelSize, marginX: marginX, marginY: marginY)
        }
    }

    @ViewBuilder
    private func renderSelection(marginX: CGFloat, marginY: CGFloat) -> some View {
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
                hoveredHandle: viewModel.hoveredHandle,
                marginX: marginX,
                marginY: marginY
            )
        }
    }

    // MARK: - Gestures

    private func dragGesture(marginX: CGFloat, marginY: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isDragging {
                    handleToolEvent(at: value.startLocation, type: .down, marginX: marginX, marginY: marginY)
                    isDragging = true
                    startDragMonitor()
                }
                handleToolEvent(at: value.location, type: .drag, marginX: marginX, marginY: marginY)
            }
            .onEnded { value in
                handleToolEvent(at: value.location, type: .up, marginX: marginX, marginY: marginY)
                isDragging = false
                stopDragMonitor()
            }
    }

    private func startDragMonitor() {
        // 드래그 중 마우스가 뷰 밖으로 나가도 추적
        dragMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp]) { event in
            guard self.isDragging else { return event }

            if event.type == .leftMouseDragged {
                // Global 좌표를 local 좌표로 변환
                let globalPoint = NSEvent.mouseLocation
                let localX = globalPoint.x - self.canvasGlobalFrame.minX
                // NSEvent는 Y 좌표가 반대이므로 변환 필요
                let screenHeight = NSScreen.main?.frame.height ?? 0
                let flippedY = screenHeight - globalPoint.y
                let localY = flippedY - self.canvasGlobalFrame.minY

                let localPoint = CGPoint(x: localX, y: localY)

                // 뷰 안에 있을 때는 DragGesture에 맡기고, 뷰 밖에서만 처리
                if localX < 0 || localX > self.canvasGlobalFrame.width || localY < 0 || localY > self.canvasGlobalFrame.height {
                    self.handleToolEvent(at: localPoint, type: .drag, marginX: self.currentMarginX, marginY: self.currentMarginY)
                }
            } else if event.type == .leftMouseUp {
                // 마우스를 놓으면 드래그 종료
                let globalPoint = NSEvent.mouseLocation
                let localX = globalPoint.x - self.canvasGlobalFrame.minX
                let screenHeight = NSScreen.main?.frame.height ?? 0
                let flippedY = screenHeight - globalPoint.y
                let localY = flippedY - self.canvasGlobalFrame.minY

                let localPoint = CGPoint(x: localX, y: localY)

                // 뷰 밖에서 마우스를 놓았을 때만 처리
                if localX < 0 || localX > self.canvasGlobalFrame.width || localY < 0 || localY > self.canvasGlobalFrame.height {
                    self.handleToolEvent(at: localPoint, type: .up, marginX: self.currentMarginX, marginY: self.currentMarginY)
                    self.isDragging = false
                    self.stopDragMonitor()
                }
            }

            return event
        }
    }

    private func stopDragMonitor() {
        if let monitor = dragMonitor {
            NSEvent.removeMonitor(monitor)
            dragMonitor = nil
        }
    }

    private enum ToolEventType {
        case down, drag, up
    }

    private func handleToolEvent(at location: CGPoint, type: ToolEventType, marginX: CGFloat, marginY: CGFloat) {
        let pixelCoord = screenToPixel(location, marginX: marginX, marginY: marginY)
        let isAltPressed = type == .down && NSEvent.modifierFlags.contains(.option)

        if viewModel.toolSettingsManager.selectedTool == .selection {
            if type == .down {
                viewModel.updateHover(x: pixelCoord.x, y: pixelCoord.y)
                if viewModel.hoveredHandle != nil || viewModel.checkInsideSelection(x: pixelCoord.x, y: pixelCoord.y) {
                    viewModel.handleToolDown(x: pixelCoord.x, y: pixelCoord.y, altPressed: isAltPressed)
                    return
                }
            } else if viewModel.selectionMode != .idle {
                handleToolAction(coord: pixelCoord, type: type)
                return
            }
        }

        guard isInsideCanvas(pixelCoord) else {
            if type == .down {
                viewModel.handleOutsideClick()
            }
            return
        }

        let clampedCoord = clampToCanvas(pixelCoord)
        handleToolAction(coord: clampedCoord, type: type)
    }

    private func handleToolAction(coord: (x: Int, y: Int), type: ToolEventType) {
        switch type {
        case .down:
            viewModel.handleToolDown(x: coord.x, y: coord.y, altPressed: NSEvent.modifierFlags.contains(.option))
        case .drag:
            viewModel.handleToolDrag(x: coord.x, y: coord.y)
        case .up:
            viewModel.handleToolUp(x: coord.x, y: coord.y)
        }
    }

    // MARK: - Hover & Cursor

    private func handleHover(phase: HoverPhase, marginX: CGFloat, marginY: CGFloat) {
        switch phase {
        case .active(let location):
            let pixelCoord = screenToPixel(location, marginX: marginX, marginY: marginY)

            if viewModel.toolSettingsManager.selectedTool == .selection {
                viewModel.updateHover(x: pixelCoord.x, y: pixelCoord.y)
                updateCursor(for: pixelCoord)
            } else if isInsideCanvas(pixelCoord) {
                viewModel.updateHover(x: pixelCoord.x, y: pixelCoord.y)
                NSCursor.crosshair.set()
            }
        case .ended:
            viewModel.clearHover()
            NSCursor.arrow.set()
        }
    }

    private func updateCursor(for coord: (x: Int, y: Int)) {
        if let handle = viewModel.hoveredHandle {
            setCursor(for: handle)
        } else if viewModel.checkInsideSelection(x: coord.x, y: coord.y) {
            NSCursor.openHand.set()
        } else {
            NSCursor.crosshair.set()
        }
    }

    private func setCursor(for handle: CanvasViewModel.ResizeHandle) {
        switch handle {
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .rotate:
            if let image = NSImage(systemSymbolName: "arrow.clockwise", accessibilityDescription: "Rotate"),
               let tinted = image.withSymbolConfiguration(.init(pointSize: 16, weight: .regular)) {
                NSCursor(image: tinted, hotSpot: NSPoint(x: 8, y: 8)).set()
            } else {
                NSCursor.crosshair.set()
            }
        default:
            NSCursor.crosshair.set()
        }
    }

    // MARK: - Coordinate Helpers

    private func screenToPixel(_ point: CGPoint, marginX: CGFloat, marginY: CGFloat) -> (x: Int, y: Int) {
        (
            x: Int((point.x - marginX) / pixelSize),
            y: Int((point.y - marginY) / pixelSize)
        )
    }

    private func isInsideCanvas(_ coord: (x: Int, y: Int)) -> Bool {
        coord.x >= 0 && coord.x < viewModel.canvas.width && coord.y >= 0 && coord.y < viewModel.canvas.height
    }

    private func clampToCanvas(_ coord: (x: Int, y: Int)) -> (x: Int, y: Int) {
        (
            x: max(0, min(coord.x, viewModel.canvas.width - 1)),
            y: max(0, min(coord.y, viewModel.canvas.height - 1))
        )
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            viewModel.shiftPressed = event.modifierFlags.contains(.shift)
            return event
        }
    }

    private func cleanupEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - Helper Views

struct CheckerboardView: View {
    let width: Int
    let height: Int
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            let lightGray = Color(white: Constants.Canvas.checkerboardLightGray)
            let darkGray = Color(white: Constants.Canvas.checkerboardDarkGray)

            for y in 0..<height {
                for x in 0..<width {
                    let isEven = (x + y) % 2 == 0
                    let rect = CGRect(
                        x: marginX + CGFloat(x) * pixelSize,
                        y: marginY + CGFloat(y) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(rect), with: .color(isEven ? lightGray : darkGray))
                }
            }
        }
    }
}

struct PixelGridView: View {
    let layer: Layer
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            for y in 0..<layer.pixels.count {
                for x in 0..<layer.pixels[y].count {
                    if let color = layer.pixels[y][x] {
                        let rect = CGRect(
                            x: marginX + CGFloat(x) * pixelSize,
                            y: marginY + CGFloat(y) * pixelSize,
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
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            let gridColor = Color(white: 0.6, opacity: 0.3)
            var path = Path()

            for x in 0...width {
                let xPos = marginX + CGFloat(x) * pixelSize
                path.move(to: CGPoint(x: xPos, y: marginY))
                path.addLine(to: CGPoint(x: xPos, y: marginY + CGFloat(height) * pixelSize))
            }

            for y in 0...height {
                let yPos = marginY + CGFloat(y) * pixelSize
                path.move(to: CGPoint(x: marginX, y: yPos))
                path.addLine(to: CGPoint(x: marginX + CGFloat(width) * pixelSize, y: yPos))
            }

            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }
}

struct ShapePreviewView: View {
    let preview: [(x: Int, y: Int, color: Color)]
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            for pixel in preview {
                let rect = CGRect(
                    x: marginX + CGFloat(pixel.x) * pixelSize,
                    y: marginY + CGFloat(pixel.y) * pixelSize,
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
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            for y in 0..<layer.pixels.count {
                for x in 0..<layer.pixels[y].count {
                    if let color = layer.pixels[y][x] {
                        let rect = CGRect(
                            x: marginX + CGFloat(x) * pixelSize,
                            y: marginY + CGFloat(y) * pixelSize,
                            width: pixelSize,
                            height: pixelSize
                        )
                        let tintedColor = color.opacity(opacity)
                        context.fill(Path(rect), with: .color(tintedColor))
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
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            let effectiveRect = CGRect(
                x: rect.minX + offset.x,
                y: rect.minY + offset.y,
                width: rect.width,
                height: rect.height
            )

            if shouldShowGhost, let origPixels = originalPixels, let origRect = originalRect {
                drawPixels(context: context, pixels: origPixels, rect: origRect, opacity: 0.3)
            }

            if let pixels = selectionPixels {
                let opacity = (isMoving || isResizing) ? 0.6 : 1.0
                drawPixels(context: context, pixels: pixels, rect: effectiveRect, opacity: opacity)
            }

            drawSelectionBorder(context: context, rect: effectiveRect)
            drawResizeHandles(context: context, rect: effectiveRect)
        }
    }

    private var shouldShowGhost: Bool {
        isMoving || isResizing
    }

    private var isResizing: Bool {
        if case .resizing = selectionMode { return true }
        return false
    }

    private func drawPixels(context: GraphicsContext, pixels: [[Color?]], rect: CGRect, opacity: Double) {
        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x] {
                    let pixelRect = CGRect(
                        x: marginX + (rect.minX + CGFloat(x)) * pixelSize,
                        y: marginY + (rect.minY + CGFloat(y)) * pixelSize,
                        width: pixelSize,
                        height: pixelSize
                    )
                    context.fill(Path(pixelRect), with: .color(color.opacity(opacity)))
                }
            }
        }
    }

    private func drawSelectionBorder(context: GraphicsContext, rect: CGRect) {
        let borderRect = CGRect(
            x: marginX + rect.minX * pixelSize,
            y: marginY + rect.minY * pixelSize,
            width: rect.width * pixelSize,
            height: rect.height * pixelSize
        )

        var path = Path()
        path.addRect(borderRect)
        context.stroke(
            path,
            with: .color(Color(red: 0.0, green: 0.5, blue: 1.0)),
            style: StrokeStyle(lineWidth: 2.5, dash: [6, 4])
        )
    }

    private func drawResizeHandles(context: GraphicsContext, rect: CGRect) {
        let borderRect = CGRect(
            x: marginX + rect.minX * pixelSize,
            y: marginY + rect.minY * pixelSize,
            width: rect.width * pixelSize,
            height: rect.height * pixelSize
        )

        let baseHandleSize: CGFloat = 11
        let handleTypes: [CanvasViewModel.ResizeHandle] = [
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .top, .bottom, .left, .right, .rotate
        ]
        let handlePositions: [(x: CGFloat, y: CGFloat)] = [
            (borderRect.minX, borderRect.minY),
            (borderRect.maxX, borderRect.minY),
            (borderRect.minX, borderRect.maxY),
            (borderRect.maxX, borderRect.maxY),
            (borderRect.midX, borderRect.minY),
            (borderRect.midX, borderRect.maxY),
            (borderRect.minX, borderRect.midY),
            (borderRect.maxX, borderRect.midY),
            (borderRect.midX, borderRect.minY - 3 * pixelSize)
        ]

        for (index, position) in handlePositions.enumerated() {
            let handleType = handleTypes[index]
            let isHovered = hoveredHandle == handleType
            let handleSize = isHovered ? baseHandleSize * 1.3 : baseHandleSize

            if handleType == .rotate {
                drawRotateHandle(context: context, position: position, size: handleSize, isHovered: isHovered, borderRect: borderRect)
            } else {
                drawResizeHandle(context: context, position: position, size: handleSize, isHovered: isHovered)
            }
        }
    }

    private func drawRotateHandle(context: GraphicsContext, position: (x: CGFloat, y: CGFloat), size: CGFloat, isHovered: Bool, borderRect: CGRect) {
        let circleRect = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)

        var linePath = Path()
        linePath.move(to: CGPoint(x: borderRect.midX, y: borderRect.minY))
        linePath.addLine(to: CGPoint(x: position.x, y: position.y))
        context.stroke(linePath, with: .color(Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.5)), lineWidth: 1.5)

        let circlePath = Path(ellipseIn: circleRect)
        let fillColor = isHovered ? Color(red: 0.4, green: 0.7, blue: 1.0, opacity: 0.7) : Color(red: 0.0, green: 0.5, blue: 1.0, opacity: 0.9)
        context.fill(circlePath, with: .color(fillColor))
        context.stroke(circlePath, with: .color(.white), lineWidth: 2)
    }

    private func drawResizeHandle(context: GraphicsContext, position: (x: CGFloat, y: CGFloat), size: CGFloat, isHovered: Bool) {
        let handleRect = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)

        context.fill(Path(handleRect), with: .color(.black.opacity(0.15)))

        let fillColor = isHovered ? Color(red: 0.4, green: 0.7, blue: 1.0, opacity: 0.5) : .white
        let borderColor = isHovered ? Color(red: 0.0, green: 0.5, blue: 1.0) : Color(red: 0.0, green: 0.45, blue: 0.9)
        let borderWidth: CGFloat = isHovered ? 2.5 : 2

        context.fill(Path(handleRect), with: .color(fillColor))
        context.stroke(Path(handleRect), with: .color(borderColor), lineWidth: borderWidth)
    }
}
