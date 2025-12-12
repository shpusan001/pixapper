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
    @Published var selectionRect: CGRect?  // 선택 영역
    @Published var selectionPixels: [[Color?]]?  // 선택된 픽셀 데이터
    @Published var selectionOffset: CGPoint = .zero  // 이동 오프셋
    @Published var isFloatingSelection: Bool = false  // 부유 선택 상태 (원본에 영향 없음)
    @Published var originalPixels: [[Color?]]?  // 선택 전 원본 픽셀 (잔상 표시용)
    @Published var originalRect: CGRect?  // 선택 전 원본 위치

    // isMovingSelection 대체: computed property
    var isMovingSelection: Bool {
        if case .moving = selectionMode {
            return true
        }
        return false
    }

    var layerViewModel: LayerViewModel
    var commandManager: CommandManager
    var toolSettingsManager: ToolSettingsManager
    weak var timelineViewModel: TimelineViewModel?  // Timeline 동기화용

    // Canvas Compositor (렌더링 레이어 합성)
    private let compositeLayerManager = CompositeLayerManager()

    private var shapeStartPoint: (x: Int, y: Int)?
    private var lastDrawPoint: (x: Int, y: Int)?
    private var currentStrokePixels: [PixelChange] = []
    private var oldStrokePixels: [PixelChange] = []
    private var drawnPixelsInStroke: Set<String> = []  // "x,y" 형식으로 저장
    private var cancellables = Set<AnyCancellable>()

    // Selection Tool - Clipboard
    private var clipboard: SelectionClipboard?

    // Selection Tool - Mode
    enum SelectionMode: Equatable {
        case idle
        case moving
        case resizing(handle: ResizeHandle)
    }
    @Published var selectionMode: SelectionMode = .idle

    // Selection Tool - Resize Handle
    enum ResizeHandle: Equatable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
    }
    private var resizeStartRect: CGRect?
    private var resizeStartPixels: [[Color?]]?
    private var moveStartRect: CGRect?
    @Published var hoveredHandle: ResizeHandle?  // 호버 중인 핸들

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

    func handleToolDown(x: Int, y: Int, altPressed: Bool = false) {
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
        case .selection:
            // 핸들 클릭 체크
            if let handle = getResizeHandle(x: x, y: y) {
                // 크기 조절 시작
                startResizingSelection(handle: handle, at: (x, y))
            }
            // 기존 선택 영역 내부를 클릭했는지 확인
            else if isInsideSelection(x: x, y: y) {
                // Alt+드래그: 선택 영역 복사하면서 이동 (Adobe 스타일)
                if altPressed {
                    guard let currentRect = selectionRect,
                          let currentPixels = selectionPixels else { return }

                    // 1. 클립보드에 복사
                    copySelection()

                    // 2. 현재 선택을 레이어에 커밋 (원본이 제자리에 남음)
                    commitSelection()

                    // 3. 같은 위치에 새 부유 선택 생성
                    selectionRect = currentRect
                    selectionPixels = currentPixels
                    originalPixels = currentPixels
                    originalRect = currentRect
                    isFloatingSelection = true

                    // 4. 이동 시작
                    startMovingSelection(at: (x, y))
                } else {
                    // 일반 선택 영역 이동 시작
                    startMovingSelection(at: (x, y))
                }
            } else {
                // 선택 영역 밖을 클릭: 기존 선택 커밋하고 새 선택 준비
                if isFloatingSelection {
                    commitSelection()
                } else if selectionRect != nil {
                    // floating 아닌 일반 선택은 취소
                    clearSelection()
                }
                // 새 선택 영역 시작점만 저장 (드래그 시작 시 선택 시작)
                shapeStartPoint = (x, y)
            }
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
        case .selection:
            switch selectionMode {
            case .moving:
                // 선택 영역 이동 중
                updateSelectionMove(to: (x, y))
            case .resizing(let handle):
                // 선택 영역 크기 조절 중
                updateSelectionResize(handle: handle, to: (x, y))
            case .idle:
                // 선택 영역 그리기 중이 아니면 호버 체크
                if shapeStartPoint == nil {
                    // 호버 중인 핸들 업데이트
                    hoveredHandle = getResizeHandle(x: x, y: y)
                } else {
                    // 선택 영역 그리기 중
                    updateSelectionRect(endX: x, endY: y)
                }
            }
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

        case .selection:
            switch selectionMode {
            case .moving:
                // 선택 영역 이동 완료
                commitSelectionMove()
            case .resizing:
                // 선택 영역 크기 조절 완료
                commitSelectionResize()
            case .idle:
                // 드래그 없이 클릭만 한 경우 (1x1 선택 방지)
                if let start = shapeStartPoint, start.x == x && start.y == y {
                    // 클릭만 했으므로 선택 취소
                    shapeStartPoint = nil
                    selectionRect = nil
                    return
                }

                // 선택 완료 - shapeStartPoint만 리셋 (selectionRect는 유지)
                shapeStartPoint = nil
                // 선택 영역 픽셀 데이터 캡처
                captureSelection()
            }

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
        // RGB 정밀 비교
        return c1.isEqual(to: c2, tolerance: Constants.Color.defaultTolerance)
    }

    // MARK: - Selection Tool

    /// 선택 영역을 업데이트합니다
    private func updateSelectionRect(endX: Int, endY: Int) {
        guard let start = shapeStartPoint else { return }

        let minX = min(start.x, endX)
        let maxX = max(start.x, endX)
        let minY = min(start.y, endY)
        let maxY = max(start.y, endY)

        selectionRect = CGRect(
            x: minX,
            y: minY,
            width: maxX - minX + 1,
            height: maxY - minY + 1
        )
    }

    /// 선택 영역의 픽셀 데이터를 캡처하고 레이어에서 즉시 제거 (Command 생성)
    func captureSelection() {
        guard let rect = selectionRect,
              currentLayerIndex < layerViewModel.layers.count else {
            selectionPixels = nil
            originalPixels = nil
            return
        }

        // 이전 선택 상태 백업
        let wasFloating = isFloatingSelection
        let oldRect = selectionRect
        let oldPixels = selectionPixels
        let oldOriginalRect = originalRect
        let oldOriginalPixels = originalPixels

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)
        let width = Int(rect.width)
        let height = Int(rect.height)

        // 1. 선택 영역의 픽셀 데이터 복사
        var pixels: [[Color?]] = []
        var layerOldPixels: [PixelChange] = []
        var layerNewPixels: [PixelChange] = []

        for y in 0..<height {
            var row: [Color?] = []
            for x in 0..<width {
                let pixelX = startX + x
                let pixelY = startY + y
                if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                    let color = layerViewModel.layers[currentLayerIndex].getPixel(x: pixelX, y: pixelY)
                    row.append(color)

                    // 색칠된 픽셀만 제거
                    if color != nil {
                        layerOldPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                        layerNewPixels.append(PixelChange(x: pixelX, y: pixelY, color: nil))
                    }
                } else {
                    row.append(nil)
                }
            }
            pixels.append(row)
        }

        // 2. 레이어에서 픽셀 제거 (Command 생성 전에 직접 실행)
        for change in layerNewPixels {
            layerViewModel.layers[currentLayerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }

        // 3. 선택 상태 설정 (Command 생성 전에 직접 실행)
        selectionPixels = pixels
        originalPixels = pixels
        originalRect = rect
        isFloatingSelection = true

        // 4. Command 생성 (이미 실행된 상태)
        if !layerOldPixels.isEmpty {
            let command = SelectionCaptureCommand(
                canvasViewModel: self,
                layerViewModel: layerViewModel,
                layerIndex: currentLayerIndex,
                wasFloating: wasFloating,
                oldRect: oldRect,
                oldPixels: oldPixels,
                oldOriginalRect: oldOriginalRect,
                oldOriginalPixels: oldOriginalPixels,
                newRect: rect,
                newPixels: pixels,
                layerOldPixels: layerOldPixels,
                layerNewPixels: layerNewPixels
            )
            commandManager.addExecutedCommand(command)
            timelineViewModel?.syncCurrentLayerToKeyframe()
        }
    }

    /// 선택 영역을 해제합니다
    func clearSelection() {
        selectionRect = nil
        selectionPixels = nil
        originalPixels = nil
        originalRect = nil
        selectionOffset = .zero
        isFloatingSelection = false
        selectionMode = .idle
    }

    /// 선택 상태를 복원 (undo/redo 지원)
    func restoreSelectionState(
        rect: CGRect?,
        pixels: [[Color?]]?,
        originalPixels: [[Color?]]?,
        originalRect: CGRect?,
        isFloating: Bool
    ) {
        selectionRect = rect
        selectionPixels = pixels
        self.originalPixels = originalPixels
        self.originalRect = originalRect
        isFloatingSelection = isFloating
        selectionOffset = .zero
        selectionMode = .idle
    }

    /// 주어진 좌표가 선택 영역 내부인지 확인
    private func isInsideSelection(x: Int, y: Int) -> Bool {
        guard let rect = selectionRect else { return false }
        return rect.contains(CGPoint(x: x, y: y))
    }

    /// 주어진 좌표가 리사이즈 핸들 위에 있는지 확인
    private func getResizeHandle(x: Int, y: Int) -> ResizeHandle? {
        guard let rect = selectionRect else { return nil }

        let handleSize: CGFloat = 2  // 픽셀 단위로 핸들 크기 (정확한 판정)
        let px = CGFloat(x)
        let py = CGFloat(y)

        let nearLeft = abs(px - rect.minX) <= handleSize
        let nearRight = abs(px - rect.maxX) <= handleSize
        let nearTop = abs(py - rect.minY) <= handleSize
        let nearBottom = abs(py - rect.maxY) <= handleSize

        // 모서리 핸들 체크 (최우선)
        if nearLeft && nearTop {
            return .topLeft
        }
        if nearRight && nearTop {
            return .topRight
        }
        if nearLeft && nearBottom {
            return .bottomLeft
        }
        if nearRight && nearBottom {
            return .bottomRight
        }

        // 가장자리 핸들 체크
        if nearTop && px >= rect.minX && px <= rect.maxX {
            return .top
        }
        if nearBottom && px >= rect.minX && px <= rect.maxX {
            return .bottom
        }
        if nearLeft && py >= rect.minY && py <= rect.maxY {
            return .left
        }
        if nearRight && py >= rect.minY && py <= rect.maxY {
            return .right
        }

        return nil
    }

    /// 호버 상태 업데이트 (선택 도구 전용)
    func updateHover(x: Int, y: Int) {
        guard toolSettingsManager.selectedTool == .selection,
              selectionMode == .idle else {
            hoveredHandle = nil
            return
        }

        hoveredHandle = getResizeHandle(x: x, y: y)
    }

    /// 호버 상태 제거
    func clearHover() {
        hoveredHandle = nil
    }

    /// 주어진 좌표가 선택 영역 내부인지 확인 (public wrapper)
    func checkInsideSelection(x: Int, y: Int) -> Bool {
        return isInsideSelection(x: x, y: y)
    }

    /// 캔버스 바깥 클릭 처리
    func handleOutsideClick() {
        // 선택 도구일 때만 선택 해제
        if toolSettingsManager.selectedTool == .selection {
            if isFloatingSelection {
                commitSelection()
            } else {
                clearSelection()
            }
        }
    }

    /// 선택 영역 이동 시작
    private func startMovingSelection(at point: (x: Int, y: Int)) {
        guard selectionPixels != nil else { return }
        selectionMode = .moving
        lastDrawPoint = point  // 시작 위치 저장
        moveStartRect = selectionRect  // 이동 전 rect 저장 (Command용)
    }

    /// 선택 영역 크기 조절 시작
    private func startResizingSelection(handle: ResizeHandle, at point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              let pixels = selectionPixels else { return }
        selectionMode = .resizing(handle: handle)
        resizeStartRect = rect
        resizeStartPixels = pixels  // 크기 조절 전 pixels 저장 (Command용)
        lastDrawPoint = point

        // 처음 선택 시점의 원본 유지 (선택 취소될 때까지 유지)
        if originalPixels == nil {
            originalPixels = pixels
            originalRect = rect
        }
    }

    /// 선택 영역 크기 조절 중
    private func updateSelectionResize(handle: ResizeHandle, to point: (x: Int, y: Int)) {
        guard let startRect = resizeStartRect,
              let last = lastDrawPoint,
              let origPixels = originalPixels else { return }

        let dx = point.x - last.x
        let dy = point.y - last.y

        var newRect = startRect

        // 핸들에 따라 rect 업데이트
        switch handle {
        case .topLeft:
            newRect.origin.x += CGFloat(dx)
            newRect.origin.y += CGFloat(dy)
            newRect.size.width -= CGFloat(dx)
            newRect.size.height -= CGFloat(dy)
        case .topRight:
            newRect.origin.y += CGFloat(dy)
            newRect.size.width += CGFloat(dx)
            newRect.size.height -= CGFloat(dy)
        case .bottomLeft:
            newRect.origin.x += CGFloat(dx)
            newRect.size.width -= CGFloat(dx)
            newRect.size.height += CGFloat(dy)
        case .bottomRight:
            newRect.size.width += CGFloat(dx)
            newRect.size.height += CGFloat(dy)
        case .top:
            newRect.origin.y += CGFloat(dy)
            newRect.size.height -= CGFloat(dy)
        case .bottom:
            newRect.size.height += CGFloat(dy)
        case .left:
            newRect.origin.x += CGFloat(dx)
            newRect.size.width -= CGFloat(dx)
        case .right:
            newRect.size.width += CGFloat(dx)
        }

        // 최소 크기 제한 (1x1)
        if newRect.width < 1 || newRect.height < 1 {
            return
        }

        selectionRect = newRect

        // 실시간으로 스케일링 미리보기
        let newWidth = Int(newRect.width)
        let newHeight = Int(newRect.height)
        selectionPixels = scalePixels(origPixels, toWidth: newWidth, toHeight: newHeight)
    }

    /// 선택 영역 크기 조절 완료 (SelectionTransformCommand 생성)
    private func commitSelectionResize() {
        guard let oldRect = resizeStartRect,
              let oldPixels = resizeStartPixels,
              let newRect = selectionRect,
              let newPixels = selectionPixels else {
            selectionMode = .idle
            resizeStartRect = nil
            resizeStartPixels = nil
            lastDrawPoint = nil
            return
        }

        // 크기가 실제로 변경되었을 때만 Command 생성
        if oldRect != newRect {
            // 선택 상태는 이미 updateSelectionResize에서 업데이트됨
            let command = SelectionTransformCommand(
                canvasViewModel: self,
                oldPixels: oldPixels,
                newPixels: newPixels,
                oldRect: oldRect,
                newRect: newRect
            )
            commandManager.addExecutedCommand(command)
        }

        // 상태 초기화
        selectionMode = .idle
        resizeStartRect = nil
        resizeStartPixels = nil
        lastDrawPoint = nil
    }

    /// 픽셀 배열을 Nearest Neighbor 방식으로 스케일링
    private func scalePixels(_ pixels: [[Color?]], toWidth newWidth: Int, toHeight newHeight: Int) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels[0].count

        var scaled: [[Color?]] = []

        for y in 0..<newHeight {
            var row: [Color?] = []
            let srcY = Int(Double(y) * Double(oldHeight) / Double(newHeight))

            for x in 0..<newWidth {
                let srcX = Int(Double(x) * Double(oldWidth) / Double(newWidth))
                row.append(pixels[srcY][srcX])
            }
            scaled.append(row)
        }

        return scaled
    }

    /// 선택 영역 이동 중 (실시간 rect 업데이트)
    private func updateSelectionMove(to point: (x: Int, y: Int)) {
        guard let last = lastDrawPoint,
              let rect = selectionRect else { return }

        let dx = point.x - last.x
        let dy = point.y - last.y

        // 실시간으로 rect 업데이트 (드래그 중 바로바로 이동)
        let newRect = CGRect(
            x: rect.minX + CGFloat(dx),
            y: rect.minY + CGFloat(dy),
            width: rect.width,
            height: rect.height
        )

        selectionRect = newRect
        lastDrawPoint = point  // 현재 위치를 새로운 기준점으로
    }

    /// 선택 영역 이동 완료 (SelectionTransformCommand 생성)
    private func commitSelectionMove() {
        guard let oldRect = moveStartRect,
              let newRect = selectionRect,
              let pixels = selectionPixels else {
            selectionMode = .idle
            lastDrawPoint = nil
            moveStartRect = nil
            return
        }

        // rect가 실제로 변경되었을 때만 Command 생성
        if oldRect != newRect {
            // 선택 상태는 이미 updateSelectionMove에서 업데이트됨
            let command = SelectionTransformCommand(
                canvasViewModel: self,
                oldPixels: pixels,  // 이동 시 pixels는 변하지 않음
                newPixels: pixels,
                oldRect: oldRect,
                newRect: newRect
            )
            commandManager.addExecutedCommand(command)
        }

        // 상태 초기화
        selectionMode = .idle
        lastDrawPoint = nil
        moveStartRect = nil
    }

    /// 선택 픽셀 적용 시 PixelChange 계산 (중복 로직 통합)
    /// - Parameters:
    ///   - pixels: 적용할 픽셀 데이터
    ///   - origPixels: 원본 위치에서 제거할 픽셀 (nil이면 pixels 사용)
    ///   - origRect: 원본 위치
    ///   - newRect: 새로운 위치
    ///   - layerIndex: 대상 레이어 인덱스
    /// - Returns: (oldPixels, newPixels) 튜플
    func calculatePixelChanges(
        pixels: [[Color?]],
        origPixels: [[Color?]]?,
        from origRect: CGRect,
        to newRect: CGRect,
        layerIndex: Int
    ) -> (old: [PixelChange], new: [PixelChange]) {
        guard layerIndex < layerViewModel.layers.count else {
            return ([], [])
        }

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        // 1. 원본 위치에서 색칠된 픽셀만 제거
        let origStartX = Int(origRect.minX)
        let origStartY = Int(origRect.minY)
        let pixelsToRemove = origPixels ?? pixels

        for y in 0..<pixelsToRemove.count {
            for x in 0..<pixelsToRemove[y].count {
                if pixelsToRemove[y][x] != nil {
                    let pixelX = origStartX + x
                    let pixelY = origStartY + y
                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldColor = layerViewModel.layers[layerIndex].getPixel(x: pixelX, y: pixelY)
                        oldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, color: nil))
                    }
                }
            }
        }

        // 2. 새 위치에 색칠된 픽셀만 배치
        let startX = Int(newRect.minX)
        let startY = Int(newRect.minY)

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x] {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldColor = layerViewModel.layers[layerIndex].getPixel(x: pixelX, y: pixelY)
                        if !oldPixels.contains(where: { $0.x == pixelX && $0.y == pixelY }) {
                            oldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        }
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                    }
                }
            }
        }

        return (oldPixels, newPixels)
    }

    /// 선택 픽셀을 레이어에 적용하는 헬퍼 함수 (중복 로직 통합)
    /// - Parameters:
    ///   - pixels: 적용할 픽셀 데이터
    ///   - origRect: 원본 위치
    ///   - newRect: 새로운 위치
    ///   - clearSelection: 적용 후 선택 해제 여부
    private func applyPixelsToLayer(
        pixels: [[Color?]],
        from origRect: CGRect,
        to newRect: CGRect,
        clearSelection: Bool = false
    ) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }

        // PixelChange 계산
        let (oldPixels, newPixels) = calculatePixelChanges(
            pixels: pixels,
            origPixels: originalPixels,
            from: origRect,
            to: newRect,
            layerIndex: currentLayerIndex
        )

        // 레이어에 적용
        for change in newPixels {
            layerViewModel.layers[currentLayerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }

        // Command 생성 및 Timeline 동기화
        if !newPixels.isEmpty {
            let command = DrawCommand(layerViewModel: layerViewModel, layerIndex: currentLayerIndex, oldPixels: oldPixels, newPixels: newPixels)
            commandManager.addExecutedCommand(command)
            timelineViewModel?.syncCurrentLayerToKeyframe()
        }

        // 선택 해제 (옵션)
        if clearSelection {
            self.clearSelection()
        }
    }

    /// 현재 위치에만 픽셀 배치 (원본 위치 제거 없음)
    /// - Parameters:
    ///   - pixels: 배치할 픽셀 데이터
    ///   - rect: 배치할 위치
    private func applyPixelsToCurrentPosition(pixels: [[Color?]], rect: CGRect) {
        guard currentLayerIndex < layerViewModel.layers.count else { return }

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        // 새 위치에만 픽셀 배치
        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x] {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: pixelX, y: pixelY)
                        oldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                        layerViewModel.layers[currentLayerIndex].setPixel(x: pixelX, y: pixelY, color: color)
                    }
                }
            }
        }

        // Command 생성 및 Timeline 동기화
        if !newPixels.isEmpty {
            let command = DrawCommand(layerViewModel: layerViewModel, layerIndex: currentLayerIndex, oldPixels: oldPixels, newPixels: newPixels)
            commandManager.addExecutedCommand(command)
            timelineViewModel?.syncCurrentLayerToKeyframe()
        }
    }

    /// 선택 영역을 최종 커밋 (현재 위치에 픽셀 배치 + Command 생성)
    func commitSelection() {
        guard let rect = selectionRect,
              let pixels = selectionPixels,
              let origRect = originalRect,
              let origPixels = originalPixels,
              isFloatingSelection,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)

        var layerOldPixels: [PixelChange] = []
        var layerNewPixels: [PixelChange] = []

        // 현재 위치에 픽셀 배치 준비 (PixelChange 계산)
        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x] {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: pixelX, y: pixelY)
                        layerOldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        layerNewPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                    }
                }
            }
        }

        // 레이어에 픽셀 배치 (Command 생성 전에 직접 실행)
        for change in layerNewPixels {
            layerViewModel.layers[currentLayerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }

        // 선택 상태 해제 (Command 생성 전에 직접 실행)
        clearSelection()

        // 커밋 Command 생성 (이미 실행된 상태)
        if !layerNewPixels.isEmpty {
            let command = SelectionCommitCommand(
                canvasViewModel: self,
                layerViewModel: layerViewModel,
                layerIndex: currentLayerIndex,
                oldRect: rect,
                oldPixels: pixels,
                oldOriginalRect: origRect,
                oldOriginalPixels: origPixels,
                layerOldPixels: layerOldPixels,
                layerNewPixels: layerNewPixels
            )
            commandManager.addExecutedCommand(command)
            timelineViewModel?.syncCurrentLayerToKeyframe()
        } else {
            // 픽셀이 없어도 선택은 해제
            clearSelection()
        }
    }

    // MARK: - Selection Transform

    /// 선택 영역을 90도 시계방향으로 회전
    func rotateSelectionCW() {
        guard let pixels = selectionPixels else { return }
        let rotated = rotatePixels90CW(pixels)
        applyTransformedSelection(rotated)
    }

    /// 선택 영역을 90도 반시계방향으로 회전
    func rotateSelectionCCW() {
        guard let pixels = selectionPixels else { return }
        let rotated = rotatePixels90CCW(pixels)
        applyTransformedSelection(rotated)
    }

    /// 선택 영역을 180도 회전
    func rotateSelection180() {
        guard let pixels = selectionPixels else { return }
        let rotated = rotatePixels180(pixels)
        applyTransformedSelection(rotated)
    }

    /// 선택 영역을 수평으로 뒤집기
    func flipSelectionHorizontal() {
        guard let pixels = selectionPixels else { return }
        let flipped = flipPixelsHorizontal(pixels)
        applyTransformedSelection(flipped)
    }

    /// 선택 영역을 수직으로 뒤집기
    func flipSelectionVertical() {
        guard let pixels = selectionPixels else { return }
        let flipped = flipPixelsVertical(pixels)
        applyTransformedSelection(flipped)
    }

    /// 변형된 픽셀을 선택 영역에 적용 (SelectionTransformCommand 생성)
    private func applyTransformedSelection(_ transformedPixels: [[Color?]]) {
        guard let oldRect = selectionRect,
              let oldPixels = selectionPixels else { return }

        let startX = Int(oldRect.minX)
        let startY = Int(oldRect.minY)
        let oldWidth = Int(oldRect.width)
        let oldHeight = Int(oldRect.height)
        let newHeight = transformedPixels.count
        let newWidth = transformedPixels[0].count

        // 중심 정렬을 위한 오프셋 계산
        let offsetX = (oldWidth - newWidth) / 2
        let offsetY = (oldHeight - newHeight) / 2

        // 새 선택 영역
        let newRect = CGRect(
            x: startX + offsetX,
            y: startY + offsetY,
            width: newWidth,
            height: newHeight
        )

        // 선택 상태 업데이트 (Command 생성 전에 직접 실행)
        selectionPixels = transformedPixels
        selectionRect = newRect

        // SelectionTransformCommand 생성 (이미 실행된 상태)
        let command = SelectionTransformCommand(
            canvasViewModel: self,
            oldPixels: oldPixels,
            newPixels: transformedPixels,
            oldRect: oldRect,
            newRect: newRect
        )
        commandManager.addExecutedCommand(command)
    }

    /// Command로부터 변형 적용 (undo/redo용)
    func applyTransformFromCommand(pixels: [[Color?]], rect: CGRect) {
        selectionPixels = pixels
        selectionRect = rect
        // originalPixels도 업데이트 (다음 변형을 위해)
        originalPixels = pixels
        originalRect = rect
    }

    /// 픽셀 배열을 90도 시계방향 회전
    private func rotatePixels90CW(_ pixels: [[Color?]]) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels[0].count
        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: oldHeight), count: oldWidth)

        for y in 0..<oldHeight {
            for x in 0..<oldWidth {
                rotated[x][oldHeight - 1 - y] = pixels[y][x]
            }
        }

        return rotated
    }

    /// 픽셀 배열을 90도 반시계방향 회전
    private func rotatePixels90CCW(_ pixels: [[Color?]]) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels[0].count
        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: oldHeight), count: oldWidth)

        for y in 0..<oldHeight {
            for x in 0..<oldWidth {
                rotated[oldWidth - 1 - x][y] = pixels[y][x]
            }
        }

        return rotated
    }

    /// 픽셀 배열을 180도 회전
    private func rotatePixels180(_ pixels: [[Color?]]) -> [[Color?]] {
        let height = pixels.count
        let width = pixels[0].count
        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                rotated[height - 1 - y][width - 1 - x] = pixels[y][x]
            }
        }

        return rotated
    }

    /// 픽셀 배열을 수평으로 뒤집기
    private func flipPixelsHorizontal(_ pixels: [[Color?]]) -> [[Color?]] {
        let height = pixels.count
        let width = pixels[0].count
        var flipped: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                flipped[y][width - 1 - x] = pixels[y][x]
            }
        }

        return flipped
    }

    /// 픽셀 배열을 수직으로 뒤집기
    private func flipPixelsVertical(_ pixels: [[Color?]]) -> [[Color?]] {
        let height = pixels.count
        let width = pixels[0].count
        var flipped: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)

        for y in 0..<height {
            for x in 0..<width {
                flipped[height - 1 - y][x] = pixels[y][x]
            }
        }

        return flipped
    }

    // MARK: - Selection Clipboard Operations

    /// 선택 영역을 클립보드에 복사
    func copySelection() {
        guard let pixels = selectionPixels,
              let rect = selectionRect else { return }

        clipboard = SelectionClipboard(
            pixels: pixels,
            width: Int(rect.width),
            height: Int(rect.height)
        )
    }

    /// 선택 영역을 클립보드에 복사하고 삭제
    func cutSelection() {
        guard let rect = selectionRect,
              let pixels = selectionPixels,
              currentLayerIndex < layerViewModel.layers.count else { return }

        // 클립보드에 복사
        clipboard = SelectionClipboard(
            pixels: pixels,
            width: Int(rect.width),
            height: Int(rect.height)
        )

        // 선택 영역 삭제
        deleteSelection()
    }

    /// 클립보드 내용을 캔버스에 붙여넣기 (Adobe 스타일: 오프셋 +10, +10)
    func pasteSelection() {
        guard let clipboardData = clipboard,
              currentLayerIndex < layerViewModel.layers.count else { return }

        // 이전 선택 상태 저장 (undo 시 복원용)
        let prevRect = selectionRect
        let prevPixels = selectionPixels
        let prevOriginalPixels = originalPixels
        let prevOriginalRect = originalRect
        let prevIsFloating = isFloatingSelection

        // 붙여넣기 위치 결정
        var pasteX: Int
        var pasteY: Int

        if let lastRect = prevRect {
            // 마지막 선택 위치에서 +10, +10 오프셋
            pasteX = Int(lastRect.minX) + 10
            pasteY = Int(lastRect.minY) + 10
        } else {
            // 선택이 없으면 캔버스 중앙
            pasteX = (canvas.width - clipboardData.width) / 2
            pasteY = (canvas.height - clipboardData.height) / 2
        }

        // 캔버스 범위 내로 제한
        pasteX = max(0, min(pasteX, canvas.width - clipboardData.width))
        pasteY = max(0, min(pasteY, canvas.height - clipboardData.height))

        // 새 선택 영역 생성 (부유 상태로 시작)
        let newRect = CGRect(
            x: pasteX,
            y: pasteY,
            width: clipboardData.width,
            height: clipboardData.height
        )

        // PasteCommand 생성 (이전 선택 커밋 + 새 선택 생성을 하나의 undo 단위로)
        let command = PasteCommand(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            layerIndex: currentLayerIndex,
            previousSelectionRect: prevRect,
            previousSelectionPixels: prevPixels,
            previousOriginalPixels: prevOriginalPixels,
            previousOriginalRect: prevOriginalRect,
            previousIsFloating: prevIsFloating,
            pastedSelectionRect: newRect,
            pastedSelectionPixels: clipboardData.pixels
        )

        // Command 실행하여 상태 변경 및 스택에 추가
        command.execute()
        commandManager.addExecutedCommand(command)
    }

    /// 선택 영역 삭제 (선택된 픽셀만 투명으로)
    func deleteSelection() {
        guard let rect = selectionRect,
              let pixels = selectionPixels,
              currentLayerIndex < layerViewModel.layers.count else { return }

        // 부유 선택 상태면 selectionPixels만 업데이트
        if isFloatingSelection {
            // 선택된 픽셀을 모두 nil로 변경
            var clearedPixels = pixels
            for y in 0..<clearedPixels.count {
                for x in 0..<clearedPixels[y].count {
                    clearedPixels[y][x] = nil
                }
            }
            selectionPixels = clearedPixels
            return
        }

        // 부유 상태가 아니면 레이어에서 선택된 픽셀만 삭제
        let startX = Int(rect.minX)
        let startY = Int(rect.minY)

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        // selectionPixels에서 nil이 아닌 위치만 삭제
        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if pixels[y][x] != nil {  // 선택된 픽셀만
                    let pixelX = startX + x
                    let pixelY = startY + y

                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldColor = layerViewModel.layers[currentLayerIndex].getPixel(x: pixelX, y: pixelY)
                        oldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, color: nil))
                        layerViewModel.layers[currentLayerIndex].setPixel(x: pixelX, y: pixelY, color: nil)
                    }
                }
            }
        }

        // Command 생성
        if !newPixels.isEmpty {
            let command = DrawCommand(layerViewModel: layerViewModel, layerIndex: currentLayerIndex, oldPixels: oldPixels, newPixels: newPixels)
            commandManager.addExecutedCommand(command)
            timelineViewModel?.syncCurrentLayerToKeyframe()
        }

        // 선택 영역 해제
        clearSelection()
    }

    /// 클립보드가 비어있지 않은지 확인
    var hasClipboard: Bool {
        return clipboard != nil
    }

    // MARK: - Compositor Methods

    /// Compositor를 통해 합성된 픽셀 배열 반환
    func getCompositePixels() -> [[Color?]] {
        // 선택 상태 생성
        var selectionState: SelectionState? = nil
        if let rect = selectionRect,
           let pixels = selectionPixels,
           isFloatingSelection {
            let opacity = isMovingSelection ? 0.6 : 1.0
            selectionState = SelectionState(
                pixels: pixels,
                rect: rect,
                offset: .zero,  // rect가 실시간 업데이트되므로 offset 불필요
                isFloating: true,
                opacity: opacity
            )
        }

        // Compositor 업데이트
        compositeLayerManager.updateCompositor(
            layers: layerViewModel.layers,
            shapePreview: shapePreview,
            selectionState: selectionState,
            canvasWidth: canvas.width,
            canvasHeight: canvas.height
        )

        // 합성된 픽셀 반환
        return compositeLayerManager.getCompositePixels(
            width: canvas.width,
            height: canvas.height
        )
    }
}

// MARK: - Selection Clipboard

/// 클립보드에 저장되는 선택 영역 데이터
struct SelectionClipboard {
    let pixels: [[Color?]]
    let width: Int
    let height: Int
}
