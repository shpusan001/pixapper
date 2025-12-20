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
    @ObservedObject var pixelStateManager: PixelStateManager
    @State private var isDragging = false
    @State private var eventMonitor: Any?
    @State private var dragMonitor: Any?
    @State private var scrollMonitor: Any?
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
                        Constants.Theme.backgroundDark

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

                        // 그래디언트 프리뷰 (Fill Tool 드래그 시)
                        renderGradientPreview(marginX: marginX, marginY: marginY)

                        // 텍스트 프리뷰 (실시간)
                        renderTextPreview(marginX: marginX, marginY: marginY)

                        // 브러시 미리보기 (연필/지우개)
                        renderBrushPreview(marginX: marginX, marginY: marginY)

                        // 선택 영역 (전체 영역)
                        renderSelection(marginX: marginX, marginY: marginY)

                        // 텍스트 입력 오버레이
                        renderTextEditOverlay(marginX: marginX, marginY: marginY)
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
                ForEach(timeline.layerViewModel.layers.indices, id: \.self) { layerIndex in
                    let layer = timeline.layerViewModel.layers[layerIndex]
                    if layer.isVisible,
                       let pixels = timeline.getEffectivePixels(frameIndex: onionFrame.frameIndex, layerId: layer.id) {
                        OnionSkinLayerView(
                            layer: Layer(name: layer.name, pixels: pixels),
                            pixelSize: pixelSize,
                            tint: onionFrame.tint,
                            opacity: onionFrame.opacity,
                            marginX: marginX,
                            marginY: marginY,
                            palette: timeline.pixelStateManager.currentPalette
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func renderCurrentLayers(marginX: CGFloat, marginY: CGFloat) -> some View {
        ForEach(viewModel.canvas.layers.indices, id: \.self) { index in
            let layer = viewModel.canvas.layers[index]
            if layer.isVisible, let timeline = timelineViewModel {
                PixelGridView(
                    layer: layer,
                    pixelStateManager: timeline.pixelStateManager,
                    pixelSize: pixelSize,
                    marginX: marginX,
                    marginY: marginY
                )
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
    private func renderGradientPreview(marginX: CGFloat, marginY: CGFloat) -> some View {
        if let preview = viewModel.gradientPreview {
            GradientPreviewView(preview: preview, pixelSize: pixelSize, marginX: marginX, marginY: marginY)
        }
    }

    @ViewBuilder
    private func renderBrushPreview(marginX: CGFloat, marginY: CGFloat) -> some View {
        // Mirror 툴은 다중 프리뷰 사용
        if viewModel.toolSettingsManager.selectedTool == .mirror && !viewModel.brushPreviewPositions.isEmpty {
            let brushSize = viewModel.toolSettingsManager.mirrorSettings.brushSize
            let brushColor = viewModel.toolSettingsManager.colorManager.primaryColor

            ForEach(viewModel.brushPreviewPositions.indices, id: \.self) { index in
                BrushPreviewView(
                    brushPos: viewModel.brushPreviewPositions[index],
                    brushSize: brushSize,
                    brushColor: brushColor,
                    isEraser: false,
                    canvasWidth: viewModel.canvas.width,
                    canvasHeight: viewModel.canvas.height,
                    pixelSize: pixelSize,
                    marginX: marginX,
                    marginY: marginY
                )
            }
        } else if let brushPos = viewModel.brushPreviewPosition {
            if viewModel.toolSettingsManager.selectedTool == .pencil {
                let brushSize = viewModel.toolSettingsManager.pencilSettings.brushSize
                let brushColor = viewModel.toolSettingsManager.colorManager.primaryColor

                BrushPreviewView(
                    brushPos: brushPos,
                    brushSize: brushSize,
                    brushColor: brushColor,
                    isEraser: false,
                    canvasWidth: viewModel.canvas.width,
                    canvasHeight: viewModel.canvas.height,
                    pixelSize: pixelSize,
                    marginX: marginX,
                    marginY: marginY
                )
            } else if viewModel.toolSettingsManager.selectedTool == .eraser {
                let brushSize = viewModel.toolSettingsManager.eraserSettings.brushSize

                BrushPreviewView(
                    brushPos: brushPos,
                    brushSize: brushSize,
                    brushColor: .gray,
                    isEraser: true,
                    canvasWidth: viewModel.canvas.width,
                    canvasHeight: viewModel.canvas.height,
                    pixelSize: pixelSize,
                    marginX: marginX,
                    marginY: marginY
                )
            } else if viewModel.toolSettingsManager.selectedTool == .dithering {
                let brushSize = viewModel.toolSettingsManager.ditheringSettings.brushSize
                let brushColor = viewModel.toolSettingsManager.colorManager.primaryColor

                BrushPreviewView(
                    brushPos: brushPos,
                    brushSize: brushSize,
                    brushColor: brushColor,
                    isEraser: false,
                    canvasWidth: viewModel.canvas.width,
                    canvasHeight: viewModel.canvas.height,
                    pixelSize: pixelSize,
                    marginX: marginX,
                    marginY: marginY
                )
            }
        }
    }

    @ViewBuilder
    private func renderSelection(marginX: CGFloat, marginY: CGFloat) -> some View {
        // Freeform path preview (while drawing)
        if !viewModel.freeformPath.isEmpty && viewModel.selectionPixels == nil {
            FreeformPathView(
                path: viewModel.freeformPath,
                pixelSize: pixelSize,
                marginX: marginX,
                marginY: marginY
            )
        }

        // Selection rect and pixels
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
                marginY: marginY,
                freeformMask: viewModel.freeformMask,
                palette: timelineViewModel?.pixelStateManager.currentPalette ?? .default
            )
        }
    }

    @ViewBuilder
    private func renderTextPreview(marginX: CGFloat, marginY: CGFloat) -> some View {
        if let textState = viewModel.textEditState {
            // 텍스트 픽셀 렌더링
            ForEach(Array(textState.previewPixels.enumerated()), id: \.offset) { _, pixel in
                Rectangle()
                    .fill(pixel.color)
                    .frame(width: pixelSize, height: pixelSize)
                    .position(
                        x: marginX + CGFloat(pixel.x) * pixelSize + pixelSize / 2,
                        y: marginY + CGFloat(pixel.y) * pixelSize + pixelSize / 2
                    )
            }

            // 커서 렌더링 (픽셀 단위, 깜박임)
            if textState.cursorVisible {
                renderTextCursor(textState: textState, marginX: marginX, marginY: marginY)
            }
        }
    }

    @ViewBuilder
    private func renderTextCursor(textState: TextEditState, marginX: CGFloat, marginY: CGFloat) -> some View {
        let cursorInfo = calculateCursorPosition(textState: textState)
        let cursorColor = viewModel.toolSettingsManager.colorManager.primaryColor

        // 커서 렌더링 (1픽셀 너비, primary color)
        ForEach(0..<cursorInfo.height, id: \.self) { offset in
            Rectangle()
                .fill(cursorColor)
                .frame(width: pixelSize, height: pixelSize)
                .position(
                    x: marginX + CGFloat(cursorInfo.x) * pixelSize + pixelSize / 2,
                    y: marginY + CGFloat(cursorInfo.y + offset) * pixelSize + pixelSize / 2
                )
        }
    }

    private func calculateCursorPosition(textState: TextEditState) -> (x: Int, y: Int, height: Int) {
        let settings = viewModel.toolSettingsManager.textSettings
        let font = NSFont.systemFont(ofSize: settings.fontSize)

        // 커서 위치
        let cursorIndex = min(textState.cursorPosition, textState.text.count)

        // 빈 텍스트면 기본 위치
        if textState.text.isEmpty || cursorIndex == 0 {
            let lineHeight = "A".size(withAttributes: [.font: font]).height
            return (Int(textState.rect.minX), Int(textState.rect.minY), Int(lineHeight))
        }

        // NSLayoutManager를 사용하여 실제 커서 위치 계산
        let textStorage = NSTextStorage(string: textState.text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: textState.rect.width, height: CGFloat.greatestFiniteMagnitude))

        textContainer.lineFragmentPadding = 0  // 여백 제거
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)
        textStorage.addAttributes([.font: font], range: NSRange(location: 0, length: textStorage.length))

        // 레이아웃 강제 계산
        layoutManager.glyphRange(for: textContainer)

        // 커서 위치의 glyph 인덱스
        let characterIndex = min(cursorIndex, textStorage.length)
        var glyphIndex: Int

        if characterIndex >= textStorage.length {
            // 텍스트 끝이면 마지막 glyph 다음 위치
            glyphIndex = layoutManager.numberOfGlyphs
        } else {
            glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        }

        // 커서가 속한 line fragment 찾기
        var lineFragmentRect = CGRect.zero
        var lineFragmentUsedRect = CGRect.zero
        var effectiveGlyphIndex = glyphIndex

        if glyphIndex >= layoutManager.numberOfGlyphs && layoutManager.numberOfGlyphs > 0 {
            // 텍스트 끝이면 마지막 glyph의 line fragment 사용
            effectiveGlyphIndex = layoutManager.numberOfGlyphs - 1
        }

        lineFragmentRect = layoutManager.lineFragmentRect(
            forGlyphAt: effectiveGlyphIndex,
            effectiveRange: nil,
            withoutAdditionalLayout: true
        )
        lineFragmentUsedRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: effectiveGlyphIndex,
            effectiveRange: nil,
            withoutAdditionalLayout: true
        )

        // 커서의 X 위치 계산
        var cursorXInFragment: CGFloat = 0
        if glyphIndex < layoutManager.numberOfGlyphs {
            let location = layoutManager.location(forGlyphAt: glyphIndex)
            cursorXInFragment = location.x
        } else if layoutManager.numberOfGlyphs > 0 {
            // 텍스트 끝이면 마지막 glyph 다음
            let location = layoutManager.location(forGlyphAt: layoutManager.numberOfGlyphs - 1)
            let lastGlyphRect = layoutManager.boundingRect(
                forGlyphRange: NSRange(location: layoutManager.numberOfGlyphs - 1, length: 1),
                in: textContainer
            )
            cursorXInFragment = location.x + lastGlyphRect.width
        }

        // 커서 위치 계산 (픽셀 좌표)
        let cursorX = Int(textState.rect.minX) + Int(cursorXInFragment)
        let cursorY = Int(textState.rect.minY) + Int(lineFragmentRect.minY)
        let cursorHeight = Int(lineFragmentUsedRect.height > 0 ? lineFragmentUsedRect.height : "A".size(withAttributes: [.font: font]).height)

        return (cursorX, cursorY, cursorHeight)
    }

    @ViewBuilder
    private func renderTextEditOverlay(marginX: CGFloat, marginY: CGFloat) -> some View {
        if let _ = viewModel.textEditState {
            TextEditOverlayView(
                textState: Binding(
                    get: { viewModel.textEditState ?? TextEditState(rect: .zero, isEditing: false) },
                    set: { viewModel.textEditState = $0 }
                ),
                viewModel: viewModel,
                pixelSize: pixelSize,
                offsetX: marginX,
                offsetY: marginY
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

        // 선택 도구는 캔버스 밖에서도 작동 가능
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
            // 새 선택 영역 시작 - 캔버스 밖에서도 가능
            handleToolAction(coord: pixelCoord, type: type)
            return
        }

        // 다른 도구들은 캔버스 내부로 제한
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

            if isInsideCanvas(pixelCoord) {
                let clampedCoord = clampToCanvas(pixelCoord)
                viewModel.updateHover(x: clampedCoord.x, y: clampedCoord.y)

                if viewModel.toolSettingsManager.selectedTool == .selection {
                    updateCursor(for: clampedCoord)
                } else if viewModel.toolSettingsManager.selectedTool == .text {
                    updateTextCursor(for: clampedCoord)
                } else {
                    NSCursor.crosshair.set()
                }
            } else {
                viewModel.clearHover()
                NSCursor.arrow.set()
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

    private func setCursor(for handle: SelectionTool.ResizeHandle) {
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

    private func updateTextCursor(for coord: (x: Int, y: Int)) {
        if let handle = viewModel.textBoxHoveredHandle {
            setTextCursor(for: handle)
        } else {
            NSCursor.iBeam.set()
        }
    }

    private func setTextCursor(for handle: TextBoxHandle) {
        switch handle {
        case .topLeft, .bottomRight:
            NSCursor.crosshair.set()  // 대각선 리사이즈
        case .topRight, .bottomLeft:
            NSCursor.crosshair.set()  // 대각선 리사이즈
        case .top, .bottom:
            NSCursor.resizeUpDown.set()
        case .left, .right:
            NSCursor.resizeLeftRight.set()
        case .inside:
            NSCursor.openHand.set()  // 이동용 손 모양
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

        // Command + Scroll로 줌 조정
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            if event.modifierFlags.contains(.command) {
                let delta = event.scrollingDeltaY
                let zoomChange = delta * 10.0 // 스크롤 감도 조정
                let newZoom = viewModel.zoomLevel + zoomChange
                viewModel.zoomLevel = max(100, min(1600, newZoom))
                return nil // 이벤트 소비 (스크롤 방지)
            }
            return event // 일반 스크롤은 그대로 전달
        }
    }

    private func cleanupEventMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollMonitor {
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
                        width: pixelSize + 1,
                        height: pixelSize + 1
                    )
                    context.fill(Path(rect), with: .color(isEven ? lightGray : darkGray))
                }
            }
        }
    }
}

struct PixelGridView: View {
    let layer: Layer
    @ObservedObject var pixelStateManager: PixelStateManager
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            // Single Source of Truth: PixelStateManager에서 픽셀 직접 조회 (Reactive)
            let pixels = pixelStateManager.currentFramePixels[layer.id] ?? []

            for y in 0..<pixels.count {
                for x in 0..<pixels[y].count {
                    let pixelValue = pixels[y][x]
                    if pixelValue != .transparent {
                        // Convert PixelValue to Color
                        let color: Color
                        switch pixelValue {
                        case .transparent:
                            continue
                        case .indexed(let colorIndex):
                            color = pixelStateManager.currentPalette.getColor(at: colorIndex) ?? .clear
                        case .gradient:
                            // RenderContext로 그래디언트 렌더링
                            let renderContext = DefaultRenderContext(
                                palette: pixelStateManager.currentPalette,
                                gradients: pixelStateManager.gradientLibrary
                            )
                            let point = PixelPoint(x, y)
                            color = renderContext.resolve(pixelValue, at: point) ?? .clear
                        case .directColor(let rgba8):
                            color = Color(
                                red: Double(rgba8.r) / 255.0,
                                green: Double(rgba8.g) / 255.0,
                                blue: Double(rgba8.b) / 255.0,
                                opacity: Double(rgba8.a) / 255.0
                            )
                        }

                        let rect = CGRect(
                            x: marginX + CGFloat(x) * pixelSize,
                            y: marginY + CGFloat(y) * pixelSize,
                            width: pixelSize + 1,
                            height: pixelSize + 1
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
            // 더 선명한 격자 색상 (밝은 회색)
            let gridColor = Color.gray.opacity(0.5)
            var path = Path()

            for x in 0...width {
                let xPos = floor(marginX + CGFloat(x) * pixelSize) + 0.5
                path.move(to: CGPoint(x: xPos, y: marginY))
                path.addLine(to: CGPoint(x: xPos, y: marginY + CGFloat(height) * pixelSize))
            }

            for y in 0...height {
                let yPos = floor(marginY + CGFloat(y) * pixelSize) + 0.5
                path.move(to: CGPoint(x: marginX, y: yPos))
                path.addLine(to: CGPoint(x: marginX + CGFloat(width) * pixelSize, y: yPos))
            }

            context.stroke(path, with: .color(gridColor), lineWidth: 1.0)
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
                    width: pixelSize + 1,
                    height: pixelSize + 1
                )
                context.fill(Path(rect), with: .color(pixel.color.opacity(Constants.Opacity.Canvas.shapePreview)))
            }
        }
    }
}

struct GradientPreviewView: View {
    let preview: GradientPreview
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            switch preview {
            case .linear(let start, let end):
                // 픽셀 좌표를 화면 좌표로 변환
                let startPoint = CGPoint(
                    x: marginX + start.x * pixelSize + pixelSize / 2,
                    y: marginY + start.y * pixelSize + pixelSize / 2
                )
                let endPoint = CGPoint(
                    x: marginX + end.x * pixelSize + pixelSize / 2,
                    y: marginY + end.y * pixelSize + pixelSize / 2
                )

                // 선 그리기
                var path = Path()
                path.move(to: startPoint)
                path.addLine(to: endPoint)
                context.stroke(path, with: .color(.blue), lineWidth: 2.0)

                // 화살표 머리 그리기
                let dx = endPoint.x - startPoint.x
                let dy = endPoint.y - startPoint.y
                let length = sqrt(dx * dx + dy * dy)
                if length > 0 {
                    let angle = atan2(dy, dx)
                    let arrowLength: CGFloat = 12
                    let arrowAngle: CGFloat = .pi / 6

                    let arrowPoint1 = CGPoint(
                        x: endPoint.x - arrowLength * cos(angle - arrowAngle),
                        y: endPoint.y - arrowLength * sin(angle - arrowAngle)
                    )
                    let arrowPoint2 = CGPoint(
                        x: endPoint.x - arrowLength * cos(angle + arrowAngle),
                        y: endPoint.y - arrowLength * sin(angle + arrowAngle)
                    )

                    var arrowPath = Path()
                    arrowPath.move(to: arrowPoint1)
                    arrowPath.addLine(to: endPoint)
                    arrowPath.addLine(to: arrowPoint2)
                    context.stroke(arrowPath, with: .color(.blue), lineWidth: 2.0)
                }

                // 시작점 원 그리기
                let startCircle = Circle()
                    .path(in: CGRect(x: startPoint.x - 4, y: startPoint.y - 4, width: 8, height: 8))
                context.fill(startCircle, with: .color(.blue))

            case .radial(let center, let radius):
                // 픽셀 좌표를 화면 좌표로 변환
                let centerPoint = CGPoint(
                    x: marginX + center.x * pixelSize + pixelSize / 2,
                    y: marginY + center.y * pixelSize + pixelSize / 2
                )
                let screenRadius = radius * pixelSize

                // 원 그리기
                let circle = Circle()
                    .path(in: CGRect(
                        x: centerPoint.x - screenRadius,
                        y: centerPoint.y - screenRadius,
                        width: screenRadius * 2,
                        height: screenRadius * 2
                    ))
                context.stroke(circle, with: .color(.blue), lineWidth: 2.0)

                // 중심점 그리기
                let centerCircle = Circle()
                    .path(in: CGRect(x: centerPoint.x - 4, y: centerPoint.y - 4, width: 8, height: 8))
                context.fill(centerCircle, with: .color(.blue))
            }
        }
    }
}

struct BrushPreviewView: View {
    let brushPos: (x: Int, y: Int)
    let brushSize: Int
    let brushColor: Color
    let isEraser: Bool
    let canvasWidth: Int
    let canvasHeight: Int
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            let radius = brushSize / 2
            for dy in -radius...radius {
                for dx in -radius...radius {
                    let px = brushPos.x + dx
                    let py = brushPos.y + dy

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

                    if px >= 0 && px < canvasWidth && py >= 0 && py < canvasHeight {
                        let rect = CGRect(
                            x: marginX + CGFloat(px) * pixelSize,
                            y: marginY + CGFloat(py) * pixelSize,
                            width: pixelSize + 1,
                            height: pixelSize + 1
                        )
                        context.fill(Path(rect), with: .color(brushColor.opacity(0.3)))
                    }
                }
            }

            // 지우개일 때 외곽선 표시
            if isEraser {
                // 브러시 영역의 바운딩 박스 계산
                var minX = brushPos.x
                var maxX = brushPos.x
                var minY = brushPos.y
                var maxY = brushPos.y

                for dy in -radius...radius {
                    for dx in -radius...radius {
                        let shouldDraw: Bool
                        if brushSize % 2 == 1 {
                            shouldDraw = true
                        } else {
                            shouldDraw = abs(dx) + abs(dy) <= radius
                        }
                        if shouldDraw {
                            minX = min(minX, brushPos.x + dx)
                            maxX = max(maxX, brushPos.x + dx)
                            minY = min(minY, brushPos.y + dy)
                            maxY = max(maxY, brushPos.y + dy)
                        }
                    }
                }

                let outlineRect = CGRect(
                    x: marginX + CGFloat(minX) * pixelSize,
                    y: marginY + CGFloat(minY) * pixelSize,
                    width: CGFloat(maxX - minX + 1) * pixelSize,
                    height: CGFloat(maxY - minY + 1) * pixelSize
                )
                var path = Path()
                path.addRect(outlineRect)
                context.stroke(
                    path,
                    with: .color(.red.opacity(0.6)),
                    lineWidth: 1.5
                )
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
    let palette: ColorPalette

    var body: some View {
        Canvas { context, size in
            for y in 0..<layer.pixels.count {
                for x in 0..<layer.pixels[y].count {
                    let pixelValue = layer.pixels[y][x]
                    if pixelValue != .transparent {
                        // Convert PixelValue to Color
                        let color: Color
                        switch pixelValue {
                        case .transparent:
                            continue
                        case .indexed(let colorIndex):
                            color = palette.getColor(at: colorIndex) ?? .clear
                        case .gradient:
                            color = .clear
                        case .directColor(let rgba8):
                            color = Color(
                                red: Double(rgba8.r) / 255.0,
                                green: Double(rgba8.g) / 255.0,
                                blue: Double(rgba8.b) / 255.0,
                                opacity: Double(rgba8.a) / 255.0
                            )
                        }

                        let rect = CGRect(
                            x: marginX + CGFloat(x) * pixelSize,
                            y: marginY + CGFloat(y) * pixelSize,
                            width: pixelSize + 1,
                            height: pixelSize + 1
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

struct FreeformPathView: View {
    let path: [(x: Int, y: Int)]
    let pixelSize: CGFloat
    let marginX: CGFloat
    let marginY: CGFloat

    var body: some View {
        Canvas { context, size in
            guard path.count > 0 else { return }

            // 드래그 중: 경로 픽셀들의 외곽선 그리기
            var borderPath = Path()

            // 경로에 포함된 픽셀을 Set으로 변환
            var pixelSet: Set<String> = []
            for point in path {
                pixelSet.insert("\(point.x),\(point.y)")
            }

            // 각 픽셀의 4방향 가장자리 체크하여 외곽선 그리기
            for point in path {
                let pixelX = marginX + CGFloat(point.x) * pixelSize
                let pixelY = marginY + CGFloat(point.y) * pixelSize

                // 위쪽 가장자리 (위에 픽셀 없으면 그리기)
                if !pixelSet.contains("\(point.x),\(point.y - 1)") {
                    borderPath.move(to: CGPoint(x: pixelX, y: pixelY))
                    borderPath.addLine(to: CGPoint(x: pixelX + pixelSize, y: pixelY))
                }

                // 아래쪽 가장자리
                if !pixelSet.contains("\(point.x),\(point.y + 1)") {
                    borderPath.move(to: CGPoint(x: pixelX, y: pixelY + pixelSize))
                    borderPath.addLine(to: CGPoint(x: pixelX + pixelSize, y: pixelY + pixelSize))
                }

                // 왼쪽 가장자리
                if !pixelSet.contains("\(point.x - 1),\(point.y)") {
                    borderPath.move(to: CGPoint(x: pixelX, y: pixelY))
                    borderPath.addLine(to: CGPoint(x: pixelX, y: pixelY + pixelSize))
                }

                // 오른쪽 가장자리
                if !pixelSet.contains("\(point.x + 1),\(point.y)") {
                    borderPath.move(to: CGPoint(x: pixelX + pixelSize, y: pixelY))
                    borderPath.addLine(to: CGPoint(x: pixelX + pixelSize, y: pixelY + pixelSize))
                }
            }

            context.stroke(
                borderPath,
                with: .color(Color.accentColor),
                style: StrokeStyle(lineWidth: 2.0, dash: [4, 2])
            )
        }
    }
}

struct SelectionRectView: View {
    let rect: CGRect
    let offset: CGPoint
    let pixelSize: CGFloat
    let selectionPixels: PixelGrid?
    let isMoving: Bool
    let originalPixels: PixelGrid?
    let originalRect: CGRect?
    let selectionMode: SelectionTool.SelectionMode
    let hoveredHandle: SelectionTool.ResizeHandle?
    let marginX: CGFloat
    let marginY: CGFloat
    let freeformMask: [[Bool]]?
    let palette: ColorPalette

    var body: some View {
        Canvas { context, size in
            let effectiveRect = CGRect(
                x: rect.minX + offset.x,
                y: rect.minY + offset.y,
                width: rect.width,
                height: rect.height
            )

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

    private func drawPixels(context: GraphicsContext, pixels: PixelGrid, rect: CGRect, opacity: Double) {
        // 항상 마스크 기반으로 렌더링 (Rectangle도 마스크 사용)
        guard let mask = freeformMask else { return }

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                guard y < mask.count && x < mask[y].count && mask[y][x] else { continue }

                let pixelValue = pixels[y][x]
                if pixelValue != .transparent {
                    // Convert PixelValue to Color
                    let color: Color
                    switch pixelValue {
                    case .transparent:
                        continue
                    case .indexed(let colorIndex):
                        color = palette.getColor(at: colorIndex) ?? .clear
                    case .gradient:
                        color = .clear
                    case .directColor(let rgba8):
                        color = Color(
                            red: Double(rgba8.r) / 255.0,
                            green: Double(rgba8.g) / 255.0,
                            blue: Double(rgba8.b) / 255.0,
                            opacity: Double(rgba8.a) / 255.0
                        )
                    }

                    let pixelRect = CGRect(
                        x: marginX + (rect.minX + CGFloat(x)) * pixelSize,
                        y: marginY + (rect.minY + CGFloat(y)) * pixelSize,
                        width: pixelSize + 1,
                        height: pixelSize + 1
                    )
                    context.fill(Path(pixelRect), with: .color(color.opacity(opacity)))
                }
            }
        }
    }

    private func drawSelectionBorder(context: GraphicsContext, rect: CGRect) {
        // 항상 마스크 외곽선 그리기 (Rectangle도 마스크 사용)
        guard let mask = freeformMask else { return }
        drawFreeformBorder(context: context, rect: rect, mask: mask)
    }

    private func drawFreeformBorder(context: GraphicsContext, rect: CGRect, mask: [[Bool]]) {
        // 마스크 경계를 따라 외곽선 그리기
        let borderWidth: CGFloat = 2

        var path = Path()

        // 각 마스크 픽셀의 4방향 가장자리 체크
        for y in 0..<mask.count {
            for x in 0..<mask[y].count {
                guard mask[y][x] else { continue }

                let pixelX = marginX + (rect.minX + CGFloat(x)) * pixelSize
                let pixelY = marginY + (rect.minY + CGFloat(y)) * pixelSize

                // 위쪽 가장자리
                if y == 0 || !mask[y - 1][x] {
                    path.move(to: CGPoint(x: pixelX, y: pixelY))
                    path.addLine(to: CGPoint(x: pixelX + pixelSize, y: pixelY))
                }

                // 아래쪽 가장자리
                if y == mask.count - 1 || !mask[y + 1][x] {
                    path.move(to: CGPoint(x: pixelX, y: pixelY + pixelSize))
                    path.addLine(to: CGPoint(x: pixelX + pixelSize, y: pixelY + pixelSize))
                }

                // 왼쪽 가장자리
                if x == 0 || !mask[y][x - 1] {
                    path.move(to: CGPoint(x: pixelX, y: pixelY))
                    path.addLine(to: CGPoint(x: pixelX, y: pixelY + pixelSize))
                }

                // 오른쪽 가장자리
                if x == mask[y].count - 1 || !mask[y][x + 1] {
                    path.move(to: CGPoint(x: pixelX + pixelSize, y: pixelY))
                    path.addLine(to: CGPoint(x: pixelX + pixelSize, y: pixelY + pixelSize))
                }
            }
        }

        context.stroke(
            path,
            with: .color(Color.accentColor),
            style: StrokeStyle(lineWidth: borderWidth, dash: [6, 4])
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
        let handleTypes: [SelectionTool.ResizeHandle] = [
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
        context.stroke(linePath, with: .color(Color.accentColor.opacity(0.5)), lineWidth: 1.5)

        let circlePath = Path(ellipseIn: circleRect)
        let fillColor = isHovered ? Color.accentColor.opacity(0.7) : Color.accentColor.opacity(0.9)
        context.fill(circlePath, with: .color(fillColor))
        context.stroke(circlePath, with: .color(.white), lineWidth: 2)
    }

    private func drawResizeHandle(context: GraphicsContext, position: (x: CGFloat, y: CGFloat), size: CGFloat, isHovered: Bool) {
        let handleRect = CGRect(x: position.x - size / 2, y: position.y - size / 2, width: size, height: size)

        context.fill(Path(handleRect), with: .color(.black.opacity(0.15)))

        let fillColor = isHovered ? Color.accentColor.opacity(0.5) : .white
        let borderColor = Color.accentColor
        let borderWidth: CGFloat = isHovered ? 2.5 : 2

        context.fill(Path(handleRect), with: .color(fillColor))
        context.stroke(Path(handleRect), with: .color(borderColor), lineWidth: borderWidth)
    }
}
