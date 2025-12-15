//
//  SelectionTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI
import Combine

/// 선택 도구
/// - Note: 선택 상태는 CanvasViewModel에 저장되며, 이 클래스는 상태를 수정하는 로직만 담당합니다.
@MainActor
class SelectionTool: BaseTool, CanvasTool {
    // MARK: - Selection State (Enums)
    enum SelectionMode: Equatable {
        case idle
        case moving
        case resizing(handle: ResizeHandle)
        case rotating
    }

    enum ResizeHandle: Equatable {
        case topLeft, topRight, bottomLeft, bottomRight
        case top, bottom, left, right
        case rotate
    }

    // MARK: - Private State (도구 내부 상태만)
    private var shapeStartPoint: (x: Int, y: Int)?
    private var lastDrawPoint: (x: Int, y: Int)?
    private var resizeStartRect: CGRect?
    private var resizeStartPixels: [[Color?]]?
    private var moveStartRect: CGRect?
    private var rotateStartAngle: Double = 0
    private var rotateStartPixels: [[Color?]]?
    private var currentRotationAngle: Double = 0
    private var clipboard: SelectionClipboard?
    private var shiftPressed: Bool = false

    // Freeform selection state
    private var freeformMask: [[Bool]]?

    // MARK: - State Accessors (CanvasViewModel의 상태에 접근)
    private var freeformPath: [(x: Int, y: Int)] {
        get { canvasViewModel?.freeformPath ?? [] }
        set { canvasViewModel?.freeformPath = newValue }
    }
    private var selectionRect: CGRect? {
        get { canvasViewModel?.selectionRect }
        set { canvasViewModel?.selectionRect = newValue }
    }

    private var selectionPixels: [[Color?]]? {
        get { canvasViewModel?.selectionPixels }
        set { canvasViewModel?.selectionPixels = newValue }
    }

    private var selectionOffset: CGPoint {
        get { canvasViewModel?.selectionOffset ?? .zero }
        set { canvasViewModel?.selectionOffset = newValue }
    }

    private var isFloatingSelection: Bool {
        get { canvasViewModel?.isFloatingSelection ?? false }
        set { canvasViewModel?.isFloatingSelection = newValue }
    }

    private var originalPixels: [[Color?]]? {
        get { canvasViewModel?.originalPixels }
        set { canvasViewModel?.originalPixels = newValue }
    }

    private var originalRect: CGRect? {
        get { canvasViewModel?.originalRect }
        set { canvasViewModel?.originalRect = newValue }
    }

    private var selectionMode: SelectionMode {
        get { canvasViewModel?.selectionMode ?? .idle }
        set { canvasViewModel?.selectionMode = newValue }
    }

    private var hoveredHandle: ResizeHandle? {
        get { canvasViewModel?.hoveredHandle }
        set { canvasViewModel?.hoveredHandle = newValue }
    }

    var isMovingSelection: Bool {
        if case .moving = selectionMode {
            return true
        }
        return false
    }

    // MARK: - CanvasTool Protocol

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        // 핸들 클릭 체크
        if let handle = getResizeHandle(x: x, y: y) {
            if handle == .rotate {
                startRotatingSelection(at: (x, y))
            } else {
                startResizingSelection(handle: handle, at: (x, y))
            }
        }
        // 기존 선택 영역 내부를 클릭했는지 확인
        else if isInsideSelection(x: x, y: y) {
            // Alt+드래그: 선택 영역 복사하면서 이동
            if altPressed {
                guard let currentRect = selectionRect,
                      let currentPixels = selectionPixels else { return }

                // 1. 클립보드에 복사
                copySelection()

                // 2. 현재 선택을 레이어에 커밋
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
                clearSelection()
            }
            // 새 선택 영역 시작
            shapeStartPoint = (x, y)

            // Freeform 모드면 경로 추적 시작
            if toolSettingsManager.selectionSettings.selectionType == .freeform {
                freeformPath = []
                freeformPath.append((x, y))
            }
        }
    }

    func handleDrag(x: Int, y: Int) {
        switch selectionMode {
        case .moving:
            updateSelectionMove(to: (x, y))
        case .resizing(let handle):
            updateSelectionResize(handle: handle, to: (x, y))
        case .rotating:
            updateSelectionRotation(to: (x, y))
        case .idle:
            if shapeStartPoint == nil {
                hoveredHandle = getResizeHandle(x: x, y: y)
            } else {
                // Freeform 모드일 때 경로 추적
                if toolSettingsManager.selectionSettings.selectionType == .freeform {
                    updateFreeformPath(x: x, y: y)
                } else {
                    // Rectangle 모드
                    updateSelectionRect(endX: x, endY: y)
                }
            }
        }
    }

    func handleUp(x: Int, y: Int) {
        switch selectionMode {
        case .moving:
            commitSelectionMove()
        case .resizing:
            commitSelectionResize()
        case .rotating:
            commitSelectionRotation()
        case .idle:
            // 드래그 없이 클릭만 한 경우
            if let start = shapeStartPoint, start.x == x && start.y == y {
                shapeStartPoint = nil
                selectionRect = nil
                freeformPath = []
                return
            }

            // 선택 완료
            shapeStartPoint = nil

            if toolSettingsManager.selectionSettings.selectionType == .freeform {
                captureFreeformSelection()
            } else {
                captureSelection()
            }
        }
    }

    func updateHover(x: Int, y: Int) {
        if selectionMode == .idle {
            hoveredHandle = getResizeHandle(x: x, y: y)
        }
    }

    func clearHover() {
        hoveredHandle = nil
    }

    func handleOutsideClick() {
        if isFloatingSelection {
            commitSelection()
        } else {
            clearSelection()
        }
    }

    // MARK: - Public Methods

    func setShiftPressed(_ pressed: Bool) {
        shiftPressed = pressed
    }

    func checkInsideSelection(x: Int, y: Int) -> Bool {
        return isInsideSelection(x: x, y: y)
    }

    // MARK: - Selection Operations

    /// 선택 영역을 업데이트합니다
    private func updateSelectionRect(endX: Int, endY: Int) {
        guard let canvas = canvasViewModel,
              let start = shapeStartPoint else { return }

        let minX = min(start.x, endX)
        let maxX = max(start.x, endX)
        let minY = min(start.y, endY)
        let maxY = max(start.y, endY)

        // 캔버스 범위로 클램프
        let clampedMinX = max(0, min(minX, canvas.canvas.width - 1))
        let clampedMaxX = max(0, min(maxX, canvas.canvas.width - 1))
        let clampedMinY = max(0, min(minY, canvas.canvas.height - 1))
        let clampedMaxY = max(0, min(maxY, canvas.canvas.height - 1))

        selectionRect = CGRect(
            x: clampedMinX,
            y: clampedMinY,
            width: clampedMaxX - clampedMinX + 1,
            height: clampedMaxY - clampedMinY + 1
        )
    }

    /// 선택 영역의 픽셀 데이터를 캡처하고 레이어에서 즉시 제거
    func captureSelection() {
        guard let rect = selectionRect,
              currentLayerIndex < layerViewModel.layers.count else {
            selectionPixels = nil
            originalPixels = nil
            return
        }

        // 이미 floating 상태면 중복 호출 방지
        guard !isFloatingSelection else { return }

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

        let layerId = layerViewModel.layers[currentLayerIndex].id

        for y in 0..<height {
            var row: [Color?] = []
            for x in 0..<width {
                let pixelX = startX + x
                let pixelY = startY + y
                if let canvas = canvasViewModel,
                   pixelX >= 0 && pixelX < canvas.canvas.width && pixelY >= 0 && pixelY < canvas.canvas.height {
                    let color = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX]
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

        // 2. 레이어에서 픽셀 제거 (TimelineViewModel 사용)
        for change in layerNewPixels {
            timelineViewModel?.setPixel(layerId: layerId, x: change.x, y: change.y, color: change.color)
        }

        // 3. 선택 상태 설정
        selectionPixels = pixels
        originalPixels = pixels
        originalRect = rect
        isFloatingSelection = true

        // 4. Command 생성
        if !layerOldPixels.isEmpty {
            let command = SelectionCaptureCommand(
                canvasViewModel: canvasViewModel!,
                layerViewModel: layerViewModel,
                timelineViewModel: timelineViewModel,
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

            // 선택 캡처 완료 시 timeline에 즉시 동기화
            timelineViewModel?.pixelStateManager?.syncToTimeline()
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
        freeformPath = []
        freeformMask = nil
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

    /// 선택 영역을 최종 커밋
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

        let layerId = layerViewModel.layers[currentLayerIndex].id

        // 현재 위치에 픽셀 배치 준비
        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x],
                   let canvas = canvasViewModel {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < canvas.canvas.width && pixelY >= 0 && pixelY < canvas.canvas.height {
                        let oldColor = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX]
                        layerOldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        layerNewPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                    }
                }
            }
        }

        // 레이어에 픽셀 배치 (TimelineViewModel 사용)
        for change in layerNewPixels {
            timelineViewModel?.setPixel(layerId: layerId, x: change.x, y: change.y, color: change.color)
        }

        // 선택 상태 해제
        clearSelection()

        // 커밋 Command 생성
        if !layerNewPixels.isEmpty {
            let command = SelectionCommitCommand(
                canvasViewModel: canvasViewModel!,
                layerViewModel: layerViewModel,
                timelineViewModel: timelineViewModel,
                layerIndex: currentLayerIndex,
                oldRect: rect,
                oldPixels: pixels,
                oldOriginalRect: origRect,
                oldOriginalPixels: origPixels,
                layerOldPixels: layerOldPixels,
                layerNewPixels: layerNewPixels
            )
            commandManager.addExecutedCommand(command)

            // 선택 커밋 완료 시 timeline에 즉시 동기화
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        } else {
            clearSelection()
        }
    }

    // MARK: - Move/Resize/Rotate Operations

    private func startMovingSelection(at point: (x: Int, y: Int)) {
        guard selectionPixels != nil else { return }
        selectionMode = .moving
        lastDrawPoint = point
        moveStartRect = selectionRect
    }

    private func updateSelectionMove(to point: (x: Int, y: Int)) {
        guard let last = lastDrawPoint,
              let rect = selectionRect else { return }

        let dx = point.x - last.x
        let dy = point.y - last.y

        let newRect = CGRect(
            x: rect.minX + CGFloat(dx),
            y: rect.minY + CGFloat(dy),
            width: rect.width,
            height: rect.height
        )

        selectionRect = newRect
        lastDrawPoint = point
    }

    private func commitSelectionMove() {
        guard let oldRect = moveStartRect,
              let newRect = selectionRect,
              let pixels = selectionPixels else {
            selectionMode = .idle
            lastDrawPoint = nil
            moveStartRect = nil
            return
        }

        if oldRect != newRect {
            let command = SelectionTransformCommand(
                canvasViewModel: canvasViewModel!,
                oldPixels: pixels,
                newPixels: pixels,
                oldRect: oldRect,
                newRect: newRect
            )
            commandManager.addExecutedCommand(command)
        }

        selectionMode = .idle
        lastDrawPoint = nil
        moveStartRect = nil
    }

    private func startResizingSelection(handle: ResizeHandle, at point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              let pixels = selectionPixels else { return }
        selectionMode = .resizing(handle: handle)
        resizeStartRect = rect
        resizeStartPixels = pixels
        lastDrawPoint = point

        if originalPixels == nil {
            originalPixels = pixels
            originalRect = rect
        }
    }

    private func updateSelectionResize(handle: ResizeHandle, to point: (x: Int, y: Int)) {
        guard let startRect = resizeStartRect,
              let last = lastDrawPoint,
              let origPixels = originalPixels else { return }

        let dx = point.x - last.x
        let dy = point.y - last.y

        var newRect = startRect

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
        case .rotate:
            return
        }

        if newRect.width < 1 || newRect.height < 1 {
            return
        }

        // Shift 키가 눌렸으면 1:1 비율 유지
        if shiftPressed {
            let size = max(abs(newRect.width), abs(newRect.height))

            switch handle {
            case .topLeft:
                newRect.origin.x = newRect.maxX - size
                newRect.origin.y = newRect.maxY - size
                newRect.size.width = size
                newRect.size.height = size
            case .topRight:
                newRect.origin.y = newRect.maxY - size
                newRect.size.width = size
                newRect.size.height = size
            case .bottomLeft:
                newRect.origin.x = newRect.maxX - size
                newRect.size.width = size
                newRect.size.height = size
            case .bottomRight:
                newRect.size.width = size
                newRect.size.height = size
            default:
                break
            }
        }

        selectionRect = newRect

        // 실시간 스케일링
        let newWidth = Int(newRect.width)
        let newHeight = Int(newRect.height)
        selectionPixels = scalePixels(origPixels, toWidth: newWidth, toHeight: newHeight)
    }

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

        if oldRect != newRect {
            let command = SelectionTransformCommand(
                canvasViewModel: canvasViewModel!,
                oldPixels: oldPixels,
                newPixels: newPixels,
                oldRect: oldRect,
                newRect: newRect
            )
            commandManager.addExecutedCommand(command)
        }

        selectionMode = .idle
        resizeStartRect = nil
        resizeStartPixels = nil
        lastDrawPoint = nil
    }

    private func startRotatingSelection(at point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              let pixels = selectionPixels else { return }
        selectionMode = .rotating
        rotateStartPixels = pixels
        lastDrawPoint = point

        let centerX = rect.midX
        let centerY = rect.midY
        rotateStartAngle = atan2(Double(point.y) - Double(centerY), Double(point.x) - Double(centerX))
        currentRotationAngle = 0

        if originalPixels == nil {
            originalPixels = pixels
            originalRect = rect
        }
    }

    private func updateSelectionRotation(to point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              let origPixels = rotateStartPixels else { return }

        let centerX = rect.midX
        let centerY = rect.midY

        let currentAngle = atan2(Double(point.y) - Double(centerY), Double(point.x) - Double(centerX))
        var angle = currentAngle - rotateStartAngle
        currentRotationAngle = angle

        // Shift 키가 눌렸으면 45도 단위로 스냅
        if shiftPressed {
            let degrees = angle * 180.0 / .pi
            let snappedDegrees = round(degrees / 45.0) * 45.0
            angle = snappedDegrees * .pi / 180.0
        }

        let rotatedPixels = rotatePixelsByAngle(origPixels, angle: angle)

        let newHeight = rotatedPixels.count
        let newWidth = rotatedPixels.isEmpty ? 0 : rotatedPixels[0].count

        let newRect = CGRect(
            x: centerX - CGFloat(newWidth) / 2,
            y: centerY - CGFloat(newHeight) / 2,
            width: CGFloat(newWidth),
            height: CGFloat(newHeight)
        )

        selectionPixels = rotatedPixels
        selectionRect = newRect
    }

    private func commitSelectionRotation() {
        guard let oldPixels = rotateStartPixels,
              let newRect = selectionRect,
              let newPixels = selectionPixels,
              originalRect != nil else {
            selectionMode = .idle
            rotateStartPixels = nil
            lastDrawPoint = nil
            return
        }

        if abs(currentRotationAngle) > 0.01 {
            let centerX = newRect.midX
            let centerY = newRect.midY
            let oldHeight = oldPixels.count
            let oldWidth = oldPixels.isEmpty ? 0 : oldPixels[0].count
            let oldRect = CGRect(
                x: centerX - CGFloat(oldWidth) / 2,
                y: centerY - CGFloat(oldHeight) / 2,
                width: CGFloat(oldWidth),
                height: CGFloat(oldHeight)
            )

            let command = SelectionTransformCommand(
                canvasViewModel: canvasViewModel!,
                oldPixels: oldPixels,
                newPixels: newPixels,
                oldRect: oldRect,
                newRect: newRect
            )
            commandManager.addExecutedCommand(command)
        }

        selectionMode = .idle
        rotateStartPixels = nil
        rotateStartAngle = 0
        currentRotationAngle = 0
        lastDrawPoint = nil
    }

    // MARK: - Transform Operations

    func rotateSelectionCW() {
        guard let pixels = selectionPixels else { return }
        let rotated = rotatePixels90CW(pixels)
        applyTransformedSelection(rotated)
    }

    func rotateSelectionCCW() {
        guard let pixels = selectionPixels else { return }
        let rotated = rotatePixels90CCW(pixels)
        applyTransformedSelection(rotated)
    }

    func rotateSelection180() {
        guard let pixels = selectionPixels else { return }
        let rotated = rotatePixels180(pixels)
        applyTransformedSelection(rotated)
    }

    func flipSelectionHorizontal() {
        guard let pixels = selectionPixels else { return }
        let flipped = flipPixelsHorizontal(pixels)
        applyTransformedSelection(flipped)
    }

    func flipSelectionVertical() {
        guard let pixels = selectionPixels else { return }
        let flipped = flipPixelsVertical(pixels)
        applyTransformedSelection(flipped)
    }

    private func applyTransformedSelection(_ transformedPixels: [[Color?]]) {
        guard let oldRect = selectionRect,
              let oldPixels = selectionPixels else { return }

        let (croppedPixels, _) = cropToContent(transformedPixels)

        let startX = Int(oldRect.minX)
        let startY = Int(oldRect.minY)
        let oldWidth = Int(oldRect.width)
        let oldHeight = Int(oldRect.height)
        let newHeight = croppedPixels.count
        let newWidth = croppedPixels[0].count

        let offsetX = (oldWidth - newWidth) / 2
        let offsetY = (oldHeight - newHeight) / 2

        let newRect = CGRect(
            x: startX + offsetX,
            y: startY + offsetY,
            width: newWidth,
            height: newHeight
        )

        selectionPixels = croppedPixels
        selectionRect = newRect

        let command = SelectionTransformCommand(
            canvasViewModel: canvasViewModel!,
            oldPixels: oldPixels,
            newPixels: croppedPixels,
            oldRect: oldRect,
            newRect: newRect
        )
        commandManager.addExecutedCommand(command)
    }

    func applyTransformFromCommand(pixels: [[Color?]], rect: CGRect) {
        selectionPixels = pixels
        selectionRect = rect
        originalPixels = pixels
        originalRect = rect
    }

    // MARK: - Clipboard Operations

    func copySelection() {
        guard let pixels = selectionPixels,
              let rect = selectionRect else { return }

        clipboard = SelectionClipboard(
            pixels: pixels,
            width: Int(rect.width),
            height: Int(rect.height)
        )
    }

    func cutSelection() {
        guard let rect = selectionRect,
              let pixels = selectionPixels,
              currentLayerIndex < layerViewModel.layers.count else { return }

        clipboard = SelectionClipboard(
            pixels: pixels,
            width: Int(rect.width),
            height: Int(rect.height)
        )

        deleteSelection()
    }

    func pasteSelection() {
        guard let canvas = canvasViewModel,
              let clipboardData = clipboard,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let prevRect = selectionRect
        let prevPixels = selectionPixels
        let prevOriginalPixels = originalPixels
        let prevOriginalRect = originalRect
        let prevIsFloating = isFloatingSelection

        var pasteX: Int
        var pasteY: Int

        if let lastRect = prevRect {
            pasteX = Int(lastRect.minX) + Constants.Selection.pasteOffset
            pasteY = Int(lastRect.minY) + Constants.Selection.pasteOffset
        } else {
            pasteX = (canvas.canvas.width - clipboardData.width) / 2
            pasteY = (canvas.canvas.height - clipboardData.height) / 2
        }

        let newRect = CGRect(
            x: pasteX,
            y: pasteY,
            width: clipboardData.width,
            height: clipboardData.height
        )

        let command = PasteCommand(
            canvasViewModel: canvas,
            layerViewModel: layerViewModel,
            timelineViewModel: timelineViewModel,
            layerIndex: currentLayerIndex,
            previousSelectionRect: prevRect,
            previousSelectionPixels: prevPixels,
            previousOriginalPixels: prevOriginalPixels,
            previousOriginalRect: prevOriginalRect,
            previousIsFloating: prevIsFloating,
            pastedSelectionRect: newRect,
            pastedSelectionPixels: clipboardData.pixels
        )

        command.execute()
        commandManager.addExecutedCommand(command)
    }

    func deleteSelection() {
        guard let canvas = canvasViewModel,
              let rect = selectionRect,
              let pixels = selectionPixels,
              currentLayerIndex < layerViewModel.layers.count else { return }

        if isFloatingSelection {
            var clearedPixels = pixels
            for y in 0..<clearedPixels.count {
                for x in 0..<clearedPixels[y].count {
                    clearedPixels[y][x] = nil
                }
            }
            selectionPixels = clearedPixels
            return
        }

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if pixels[y][x] != nil {
                    let pixelX = startX + x
                    let pixelY = startY + y

                    if pixelX >= 0 && pixelX < canvas.canvas.width && pixelY >= 0 && pixelY < canvas.canvas.height {
                        let layerId = layerViewModel.layers[currentLayerIndex].id
                        let oldColor = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX]
                        oldPixels.append(PixelChange(x: pixelX, y: pixelY, color: oldColor))
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, color: nil))
                        timelineViewModel?.setPixel(layerId: layerId, x: pixelX, y: pixelY, color: nil)
                    }
                }
            }
        }

        if !newPixels.isEmpty {
            let layerId = layerViewModel.layers[currentLayerIndex].id
            let command = DrawCommand(
                timelineViewModel: timelineViewModel,
                layerId: layerId,
                oldPixels: oldPixels,
                newPixels: newPixels
            )
            commandManager.addExecutedCommand(command)

            // 선택 삭제 완료 시 timeline에 즉시 동기화
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }

        clearSelection()
    }

    var hasClipboard: Bool {
        return clipboard != nil
    }

    // MARK: - Helper Methods

    private func isInsideSelection(x: Int, y: Int) -> Bool {
        guard let rect = selectionRect else { return false }
        return rect.contains(CGPoint(x: x, y: y))
    }

    private func getResizeHandle(x: Int, y: Int) -> ResizeHandle? {
        guard let rect = selectionRect else { return nil }

        let handleSize = Constants.Selection.handleSize
        let px = CGFloat(x)
        let py = CGFloat(y)

        // 회전 핸들 체크
        let centerX = rect.midX
        let rotateY = rect.minY - Constants.Selection.rotateHandleDistance
        let rotateHandleSize = Constants.Selection.rotateHandleSize
        if abs(px - centerX) <= rotateHandleSize && abs(py - rotateY) <= rotateHandleSize {
            return .rotate
        }

        let nearLeft = abs(px - rect.minX) <= handleSize
        let nearRight = abs(px - rect.maxX) <= handleSize
        let nearTop = abs(py - rect.minY) <= handleSize
        let nearBottom = abs(py - rect.maxY) <= handleSize

        // 모서리 핸들
        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }

        // 가장자리 핸들
        if nearTop && px >= rect.minX && px <= rect.maxX { return .top }
        if nearBottom && px >= rect.minX && px <= rect.maxX { return .bottom }
        if nearLeft && py >= rect.minY && py <= rect.maxY { return .left }
        if nearRight && py >= rect.minY && py <= rect.maxY { return .right }

        return nil
    }

    // MARK: - Pixel Manipulation

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

    private func rotatePixelsByAngle(_ pixels: [[Color?]], angle: Double) -> [[Color?]] {
        let oldHeight = pixels.count
        let oldWidth = pixels.isEmpty ? 0 : pixels[0].count
        let pivotX = Double(oldWidth) / 2.0
        let pivotY = Double(oldHeight) / 2.0

        guard !pixels.isEmpty else { return [] }

        let corners = [
            (0.0, 0.0),
            (Double(oldWidth), 0.0),
            (0.0, Double(oldHeight)),
            (Double(oldWidth), Double(oldHeight))
        ]

        var minX = Double.infinity
        var maxX = -Double.infinity
        var minY = Double.infinity
        var maxY = -Double.infinity

        for (x, y) in corners {
            let dx = x - pivotX
            let dy = y - pivotY
            let rotatedX = dx * cos(angle) - dy * sin(angle)
            let rotatedY = dx * sin(angle) + dy * cos(angle)

            minX = min(minX, rotatedX)
            maxX = max(maxX, rotatedX)
            minY = min(minY, rotatedY)
            maxY = max(maxY, rotatedY)
        }

        let newWidth = Int(ceil(maxX - minX))
        let newHeight = Int(ceil(maxY - minY))

        var rotated: [[Color?]] = Array(repeating: Array(repeating: nil, count: newWidth), count: newHeight)

        for y in 0..<newHeight {
            for x in 0..<newWidth {
                let dx = Double(x) + minX
                let dy = Double(y) + minY

                let srcX = dx * cos(-angle) - dy * sin(-angle) + pivotX
                let srcY = dx * sin(-angle) + dy * cos(-angle) + pivotY

                let srcXInt = Int(round(srcX))
                let srcYInt = Int(round(srcY))

                if srcXInt >= 0 && srcXInt < oldWidth && srcYInt >= 0 && srcYInt < oldHeight {
                    rotated[y][x] = pixels[srcYInt][srcXInt]
                }
            }
        }

        return rotated
    }

    private func cropToContent(_ pixels: [[Color?]]) -> ([[Color?]], (x: Int, y: Int)) {
        guard !pixels.isEmpty, !pixels[0].isEmpty else {
            return (pixels, (0, 0))
        }

        var minX = pixels[0].count
        var minY = pixels.count
        var maxX = -1
        var maxY = -1

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if pixels[y][x] != nil {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        if maxX < 0 {
            return ([[nil]], (0, 0))
        }

        let cropWidth = maxX - minX + 1
        let cropHeight = maxY - minY + 1
        var cropped: [[Color?]] = Array(repeating: Array(repeating: nil, count: cropWidth), count: cropHeight)

        for y in 0..<cropHeight {
            for x in 0..<cropWidth {
                cropped[y][x] = pixels[minY + y][minX + x]
            }
        }

        return (cropped, (minX, minY))
    }

    // MARK: - Freeform Selection

    /// Freeform 경로를 업데이트합니다 (드래그 중)
    private func updateFreeformPath(x: Int, y: Int) {
        guard let canvas = canvasViewModel else { return }

        // 이전 점과 현재 점 사이를 브레센햄 알고리즘으로 채움
        if let last = lastDrawPoint {
            let points = bresenhamLine(x0: last.x, y0: last.y, x1: x, y1: y)
            for point in points {
                if point.x >= 0 && point.x < canvas.canvas.width &&
                   point.y >= 0 && point.y < canvas.canvas.height {
                    freeformPath.append(point)
                }
            }
        } else {
            // 첫 점
            if x >= 0 && x < canvas.canvas.width &&
               y >= 0 && y < canvas.canvas.height {
                freeformPath.append((x, y))
            }
        }

        lastDrawPoint = (x, y)

        // 경로의 bounding box 계산
        if freeformPath.count > 0 {
            var minX = Int.max
            var maxX = Int.min
            var minY = Int.max
            var maxY = Int.min

            for point in freeformPath {
                minX = min(minX, point.x)
                maxX = max(maxX, point.x)
                minY = min(minY, point.y)
                maxY = max(maxY, point.y)
            }

            selectionRect = CGRect(
                x: minX,
                y: minY,
                width: maxX - minX + 1,
                height: maxY - minY + 1
            )
        }
    }

    /// Freeform 선택을 캡처합니다
    private func captureFreeformSelection() {
        guard let rect = selectionRect,
              freeformPath.count > 0,
              currentLayerIndex < layerViewModel.layers.count else {
            selectionPixels = nil
            originalPixels = nil
            freeformPath = []
            return
        }

        // 이미 floating 상태면 중복 호출 방지
        guard !isFloatingSelection else { return }

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)
        let width = Int(rect.width)
        let height = Int(rect.height)

        // 선택된 픽셀만 마스크로 표시
        var mask: [[Bool]] = Array(repeating: Array(repeating: false, count: width), count: height)
        for point in freeformPath {
            let x = point.x - startX
            let y = point.y - startY
            if x >= 0 && x < width && y >= 0 && y < height {
                mask[y][x] = true
            }
        }

        // 마스크된 영역의 픽셀 데이터 복사 및 레이어에서 제거
        var pixels: [[Color?]] = Array(repeating: Array(repeating: nil, count: width), count: height)
        var layerOldPixels: [PixelChange] = []
        var layerNewPixels: [PixelChange] = []

        let layerId = layerViewModel.layers[currentLayerIndex].id

        for y in 0..<height {
            for x in 0..<width {
                if mask[y][x] {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if let canvas = canvasViewModel,
                       pixelX >= 0 && pixelX < canvas.canvas.width &&
                       pixelY >= 0 && pixelY < canvas.canvas.height {
                        let color = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX]
                        pixels[y][x] = color

                        // 색칠된 픽셀만 제거
                        if color != nil {
                            layerOldPixels.append(PixelChange(x: pixelX, y: pixelY, color: color))
                            layerNewPixels.append(PixelChange(x: pixelX, y: pixelY, color: nil))
                        }
                    }
                }
            }
        }

        // 레이어에서 픽셀 제거
        for change in layerNewPixels {
            timelineViewModel?.setPixel(layerId: layerId, x: change.x, y: change.y, color: change.color)
        }

        // 선택 상태 설정
        selectionPixels = pixels
        originalPixels = pixels
        originalRect = rect
        isFloatingSelection = true
        freeformMask = mask

        // Command 생성
        if !layerOldPixels.isEmpty {
            let command = SelectionCaptureCommand(
                canvasViewModel: canvasViewModel!,
                layerViewModel: layerViewModel,
                timelineViewModel: timelineViewModel,
                layerIndex: currentLayerIndex,
                wasFloating: false,
                oldRect: nil,
                oldPixels: nil,
                oldOriginalRect: nil,
                oldOriginalPixels: nil,
                newRect: rect,
                newPixels: pixels,
                layerOldPixels: layerOldPixels,
                layerNewPixels: layerNewPixels
            )
            commandManager.addExecutedCommand(command)
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }

        // 정리
        freeformPath = []
        lastDrawPoint = nil
    }

    /// 브레센햄 직선 알고리즘
    private func bresenhamLine(x0: Int, y0: Int, x1: Int, y1: Int) -> [(x: Int, y: Int)] {
        var points: [(x: Int, y: Int)] = []

        let dx = abs(x1 - x0)
        let dy = abs(y1 - y0)
        let sx = x0 < x1 ? 1 : -1
        let sy = y0 < y1 ? 1 : -1
        var err = dx - dy
        var x = x0
        var y = y0

        while true {
            points.append((x, y))

            if x == x1 && y == y1 {
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

        return points
    }
}

// MARK: - Selection Clipboard

struct SelectionClipboard {
    let pixels: [[Color?]]
    let width: Int
    let height: Int
}
