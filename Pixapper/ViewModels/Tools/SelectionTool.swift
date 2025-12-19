//
//  SelectionTool.swift
//  Pixapper
//
//  리팩토링: 1,594줄 → ~600줄
//  - SelectionState로 상태 통합
//  - PixelTransform으로 변환 로직 분리
//  - FreeformSelector로 경로 처리 분리
//

import SwiftUI
import Combine

@MainActor
class SelectionTool: BaseTool, CanvasTool {
    // MARK: - Enums
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

    // MARK: - State
    private var state = SelectionState()
    private let freeformSelector = FreeformSelector()

    // MARK: - CanvasViewModel State Accessors
    private var freeformPath: [(x: Int, y: Int)] {
        get { canvasViewModel?.freeformPath ?? [] }
        set { canvasViewModel?.freeformPath = newValue }
    }
    private var freeformMask: [[Bool]]? {
        get { canvasViewModel?.freeformMask }
        set { canvasViewModel?.freeformMask = newValue }
    }
    private var selectionRect: CGRect? {
        get { canvasViewModel?.selectionRect }
        set { canvasViewModel?.selectionRect = newValue }
    }
    private var selectionPixels: PixelGrid? {
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
    private var originalPixels: PixelGrid? {
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
        if let handle = getResizeHandle(x: x, y: y) {
            if handle == .rotate {
                startRotatingSelection(at: (x, y))
            } else {
                startResizingSelection(handle: handle, at: (x, y))
            }
        }
        else if isInsideSelection(x: x, y: y) {
            if altPressed {
                guard let currentRect = selectionRect,
                      let currentPixels = selectionPixels else { return }

                copySelection()
                commitSelection()

                selectionRect = currentRect
                selectionPixels = currentPixels
                originalPixels = currentPixels
                originalRect = currentRect
                isFloatingSelection = true

                startMovingSelection(at: (x, y))
            } else {
                startMovingSelection(at: (x, y))
            }
        } else {
            if isFloatingSelection {
                commitSelection()
            }
            clearSelection()

            state.shapeStartPoint = (x, y)
            state.lastDrawPoint = nil

            if toolSettingsManager.selectionSettings.selectionType == .freeform {
                freeformPath = []
                freeformPath.append((x, y))
                state.lastDrawPoint = (x, y)
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
            if state.shapeStartPoint == nil {
                hoveredHandle = getResizeHandle(x: x, y: y)
            } else {
                if toolSettingsManager.selectionSettings.selectionType == .freeform {
                    updateFreeformPath(x: x, y: y)
                } else {
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
            if let start = state.shapeStartPoint, start.x == x && start.y == y {
                state.shapeStartPoint = nil
                selectionRect = nil
                freeformPath = []
                return
            }

            state.shapeStartPoint = nil

            if toolSettingsManager.selectionSettings.selectionType == .freeform {
                closeFreeformPath()
            }

            captureSelection()
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
        state.shiftPressed = pressed
    }

    func checkInsideSelection(x: Int, y: Int) -> Bool {
        return isInsideSelection(x: x, y: y)
    }

    // MARK: - Selection Operations

    private func updateSelectionRect(endX: Int, endY: Int) {
        guard let canvas = canvasViewModel,
              let start = state.shapeStartPoint else { return }

        let minX = min(start.x, endX)
        let maxX = max(start.x, endX)
        let minY = min(start.y, endY)
        let maxY = max(start.y, endY)

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

    func captureSelection() {
        guard let rect = selectionRect,
              currentLayerIndex < layerViewModel.layers.count else {
            selectionPixels = nil
            originalPixels = nil
            freeformPath = []
            return
        }

        guard !isFloatingSelection else { return }

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)
        let width = Int(rect.width)
        let height = Int(rect.height)

        var mask: [[Bool]]

        if toolSettingsManager.selectionSettings.selectionType == .freeform {
            mask = Array(repeating: Array(repeating: false, count: width), count: height)

            for point in freeformPath {
                let x = point.x - startX
                let y = point.y - startY
                if x >= 0 && x < width && y >= 0 && y < height {
                    mask[y][x] = true
                }
            }

            freeformSelector.fillInterior(mask: &mask, path: freeformPath, startX: startX, startY: startY)
        } else {
            mask = Array(repeating: Array(repeating: true, count: width), count: height)
        }

        var pixels: PixelGrid = Array(repeating: Array(repeating: .transparent, count: width), count: height)
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
                        let pixelValue = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX] ?? .transparent
                        pixels[y][x] = pixelValue

                        if pixelValue != .transparent {
                            layerOldPixels.append(PixelChange(x: pixelX, y: pixelY, value: pixelValue))
                            layerNewPixels.append(PixelChange(x: pixelX, y: pixelY, value: .transparent))
                        }
                    }
                }
            }
        }

        for change in layerNewPixels {
            timelineViewModel?.setPixel(layerId: layerId, x: change.x, y: change.y, value: change.value)
        }

        selectionPixels = pixels
        originalPixels = pixels
        originalRect = rect
        isFloatingSelection = true
        freeformMask = mask

        state.resetTransformState()

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
                oldFreeformMask: nil,
                newRect: rect,
                newPixels: pixels,
                newFreeformMask: mask,
                layerOldPixels: layerOldPixels,
                layerNewPixels: layerNewPixels
            )
            commandManager.addExecutedCommand(command)
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }
    }

    func cancelSelection() {
        if isFloatingSelection,
           let origPixels = originalPixels,
           let origRect = originalRect,
           let canvas = canvasViewModel,
           currentLayerIndex < layerViewModel.layers.count {

            let layerId = layerViewModel.layers[currentLayerIndex].id
            let startX = Int(origRect.minX)
            let startY = Int(origRect.minY)

            for y in 0..<origPixels.count {
                for x in 0..<origPixels[y].count {
                    let pixelX = startX + x
                    let pixelY = startY + y

                    if pixelX >= 0 && pixelX < canvas.canvas.width && pixelY >= 0 && pixelY < canvas.canvas.height {
                        timelineViewModel?.setPixel(layerId: layerId, x: pixelX, y: pixelY, value: origPixels[y][x])
                    }
                }
            }

            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }

        clearSelection()
    }

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

        state.resetTransformState()
    }

    func restoreSelectionState(
        rect: CGRect?,
        pixels: PixelGrid?,
        originalPixels: PixelGrid?,
        originalRect: CGRect?,
        isFloating: Bool,
        freeformMask: [[Bool]]? = nil
    ) {
        selectionRect = rect
        selectionPixels = pixels
        self.originalPixels = originalPixels
        self.originalRect = originalRect
        isFloatingSelection = isFloating
        self.freeformMask = freeformMask
        selectionOffset = .zero
        selectionMode = .idle
    }

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

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                let pixelValue = pixels[y][x]
                if pixelValue != .transparent,
                   let canvas = canvasViewModel {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < canvas.canvas.width && pixelY >= 0 && pixelY < canvas.canvas.height {
                        let oldValue = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX] ?? .transparent
                        layerOldPixels.append(PixelChange(x: pixelX, y: pixelY, value: oldValue))
                        layerNewPixels.append(PixelChange(x: pixelX, y: pixelY, value: pixelValue))
                    }
                }
            }
        }

        for change in layerNewPixels {
            timelineViewModel?.setPixel(layerId: layerId, x: change.x, y: change.y, value: change.value)
        }

        clearSelection()

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
                oldFreeformMask: freeformMask,
                layerOldPixels: layerOldPixels,
                layerNewPixels: layerNewPixels
            )
            commandManager.addExecutedCommand(command)
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        } else {
            clearSelection()
        }
    }

    // MARK: - Move/Resize/Rotate Operations

    private func startMovingSelection(at point: (x: Int, y: Int)) {
        guard selectionPixels != nil else { return }
        selectionMode = .moving
        state.lastDrawPoint = point
        state.moveStartRect = selectionRect
    }

    private func updateSelectionMove(to point: (x: Int, y: Int)) {
        guard let last = state.lastDrawPoint,
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
        state.lastDrawPoint = point
    }

    private func commitSelectionMove() {
        guard let oldRect = state.moveStartRect,
              let newRect = selectionRect,
              let pixels = selectionPixels else {
            selectionMode = .idle
            state.resetMoveState()
            return
        }

        if oldRect != newRect {
            let command = SelectionTransformCommand(
                canvasViewModel: canvasViewModel!,
                oldPixels: pixels,
                newPixels: pixels,
                oldRect: oldRect,
                newRect: newRect,
                oldMask: freeformMask,
                newMask: freeformMask
            )
            commandManager.addExecutedCommand(command)
        }

        selectionMode = .idle
        state.resetMoveState()
    }

    private func startResizingSelection(handle: ResizeHandle, at point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              var pixels = selectionPixels,
              let mask = freeformMask else { return }

        PixelTransform.applyMask(to: &pixels, mask: mask)
        selectionPixels = pixels

        selectionMode = .resizing(handle: handle)
        state.resizeStartRect = rect
        state.resizeStartPixels = pixels
        state.resizeStartMask = mask
        state.lastDrawPoint = point

        if originalPixels == nil {
            originalPixels = pixels
            originalRect = rect
        }
    }

    private func updateSelectionResize(handle: ResizeHandle, to point: (x: Int, y: Int)) {
        guard let startRect = state.resizeStartRect,
              let last = state.lastDrawPoint,
              let origPixels = originalPixels,
              let origRect = originalRect else { return }

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

        if state.shiftPressed {
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

        let rotatedBoundingBox = PixelTransform.calculateRotatedBoundingBox(
            width: origRect.width,
            height: origRect.height,
            angle: state.accumulatedRotation
        )

        let scaleX = newRect.width / rotatedBoundingBox.width
        let scaleY = newRect.height / rotatedBoundingBox.height

        let targetWidth = Int(origRect.width * scaleX)
        let targetHeight = Int(origRect.height * scaleY)
        let scaledPixels = PixelTransform.scale(origPixels, toWidth: targetWidth, toHeight: targetHeight)

        let transformedPixels: PixelGrid
        if abs(state.accumulatedRotation) > 0.001 {
            transformedPixels = PixelTransform.rotateByAngle(scaledPixels, angle: state.accumulatedRotation)
        } else {
            transformedPixels = scaledPixels
        }

        selectionPixels = transformedPixels
        freeformMask = PixelTransform.createMask(from: transformedPixels)
    }

    private func commitSelectionResize() {
        guard let oldRect = state.resizeStartRect,
              let oldPixels = state.resizeStartPixels,
              let oldMask = state.resizeStartMask,
              let newRect = selectionRect,
              let newPixels = selectionPixels,
              let newMask = freeformMask else {
            selectionMode = .idle
            state.resetResizeState()
            return
        }

        if oldRect != newRect {
            let command = SelectionTransformCommand(
                canvasViewModel: canvasViewModel!,
                oldPixels: oldPixels,
                newPixels: newPixels,
                oldRect: oldRect,
                newRect: newRect,
                oldMask: oldMask,
                newMask: newMask
            )
            commandManager.addExecutedCommand(command)
        }

        originalPixels = newPixels
        originalRect = newRect
        state.resetTransformState()

        selectionMode = .idle
        state.resetResizeState()
    }

    private func startRotatingSelection(at point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              var pixels = selectionPixels,
              let mask = freeformMask else { return }

        PixelTransform.applyMask(to: &pixels, mask: mask)
        selectionPixels = pixels

        selectionMode = .rotating
        state.rotateStartPixels = pixels
        state.rotateStartMask = mask
        state.lastDrawPoint = point

        let centerX = rect.midX
        let centerY = rect.midY
        state.rotateStartAngle = atan2(Double(point.y) - Double(centerY), Double(point.x) - Double(centerX))
        state.currentRotationAngle = 0

        if originalPixels == nil {
            originalPixels = pixels
            originalRect = rect
        }

        if let origRect = originalRect {
            state.accumulatedScale = CGSize(
                width: rect.width / origRect.width,
                height: rect.height / origRect.height
            )
        }
    }

    private func updateSelectionRotation(to point: (x: Int, y: Int)) {
        guard let rect = selectionRect,
              let origPixels = originalPixels else { return }

        let centerX = rect.midX
        let centerY = rect.midY

        let currentAngle = atan2(Double(point.y) - Double(centerY), Double(point.x) - Double(centerX))
        var angle = currentAngle - state.rotateStartAngle
        state.currentRotationAngle = angle

        if state.shiftPressed {
            let degrees = angle * 180.0 / .pi
            let snappedDegrees = round(degrees / 45.0) * 45.0
            angle = snappedDegrees * .pi / 180.0
        }

        let scaledPixels: PixelGrid
        if abs(state.accumulatedScale.width - 1.0) > 0.001 || abs(state.accumulatedScale.height - 1.0) > 0.001 {
            let targetWidth = Int(Double(origPixels[0].count) * state.accumulatedScale.width)
            let targetHeight = Int(Double(origPixels.count) * state.accumulatedScale.height)
            scaledPixels = PixelTransform.scale(origPixels, toWidth: targetWidth, toHeight: targetHeight)
        } else {
            scaledPixels = origPixels
        }

        let rotatedPixels = PixelTransform.rotateByAngle(scaledPixels, angle: angle)

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
        freeformMask = PixelTransform.createMask(from: rotatedPixels)

        state.accumulatedRotation = angle
    }

    private func commitSelectionRotation() {
        guard let oldPixels = state.rotateStartPixels,
              let oldMask = state.rotateStartMask,
              let newRect = selectionRect,
              let newPixels = selectionPixels,
              let newMask = freeformMask,
              originalRect != nil else {
            selectionMode = .idle
            state.resetRotateState()
            return
        }

        if abs(state.currentRotationAngle) > 0.01 {
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
                newRect: newRect,
                oldMask: oldMask,
                newMask: newMask
            )
            commandManager.addExecutedCommand(command)
        }

        originalPixels = newPixels
        originalRect = newRect
        state.resetTransformState()

        selectionMode = .idle
        state.resetRotateState()
    }

    // MARK: - Transform Operations

    func rotateSelectionCW() {
        guard let pixels = selectionPixels else { return }
        let rotated = PixelTransform.rotate90CW(pixels)
        applyTransformedSelection(rotated)
    }

    func rotateSelectionCCW() {
        guard let pixels = selectionPixels else { return }
        let rotated = PixelTransform.rotate90CCW(pixels)
        applyTransformedSelection(rotated)
    }

    func rotateSelection180() {
        guard let pixels = selectionPixels else { return }
        let rotated = PixelTransform.rotate180(pixels)
        applyTransformedSelection(rotated)
    }

    func flipSelectionHorizontal() {
        guard let pixels = selectionPixels else { return }
        let flipped = PixelTransform.flipHorizontal(pixels)
        applyTransformedSelection(flipped)
    }

    func flipSelectionVertical() {
        guard let pixels = selectionPixels else { return }
        let flipped = PixelTransform.flipVertical(pixels)
        applyTransformedSelection(flipped)
    }

    private func applyTransformedSelection(_ transformedPixels: PixelGrid) {
        guard let oldRect = selectionRect,
              var oldPixels = selectionPixels,
              let oldMask = freeformMask else { return }

        PixelTransform.applyMask(to: &oldPixels, mask: oldMask)
        selectionPixels = oldPixels

        let finalPixels = transformedPixels

        let startX = Int(oldRect.minX)
        let startY = Int(oldRect.minY)
        let oldWidth = Int(oldRect.width)
        let oldHeight = Int(oldRect.height)
        let newHeight = transformedPixels.count
        let newWidth = transformedPixels[0].count

        let offsetX = (oldWidth - newWidth) / 2
        let offsetY = (oldHeight - newHeight) / 2

        let newRect = CGRect(
            x: startX + offsetX,
            y: startY + offsetY,
            width: newWidth,
            height: newHeight
        )

        selectionPixels = finalPixels
        selectionRect = newRect

        let newMask = PixelTransform.createMask(from: finalPixels)
        freeformMask = newMask

        let command = SelectionTransformCommand(
            canvasViewModel: canvasViewModel!,
            oldPixels: oldPixels,
            newPixels: finalPixels,
            oldRect: oldRect,
            newRect: newRect,
            oldMask: oldMask,
            newMask: newMask
        )
        commandManager.addExecutedCommand(command)
    }

    func applyTransformFromCommand(pixels: PixelGrid, rect: CGRect) {
        selectionPixels = pixels
        selectionRect = rect
        originalPixels = pixels
        originalRect = rect
    }

    // MARK: - Clipboard Operations

    func copySelection() {
        guard let pixels = selectionPixels,
              let rect = selectionRect else { return }

        state.clipboard = SelectionClipboard(
            pixels: pixels,
            width: Int(rect.width),
            height: Int(rect.height)
        )
    }

    func cutSelection() {
        guard let rect = selectionRect,
              let pixels = selectionPixels,
              currentLayerIndex < layerViewModel.layers.count else { return }

        state.clipboard = SelectionClipboard(
            pixels: pixels,
            width: Int(rect.width),
            height: Int(rect.height)
        )

        deleteSelection()
    }

    func pasteSelection() {
        guard let canvas = canvasViewModel,
              let clipboardData = state.clipboard,
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
            previousFreeformMask: freeformMask,
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

        let startX = Int(rect.minX)
        let startY = Int(rect.minY)

        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if pixels[y][x] != .transparent {
                    let pixelX = startX + x
                    let pixelY = startY + y

                    if pixelX >= 0 && pixelX < canvas.canvas.width && pixelY >= 0 && pixelY < canvas.canvas.height {
                        let layerId = layerViewModel.layers[currentLayerIndex].id
                        let oldValue = timelineViewModel?.getCurrentFramePixels(layerId: layerId)?[pixelY][pixelX] ?? .transparent
                        oldPixels.append(PixelChange(x: pixelX, y: pixelY, value: oldValue))
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, value: .transparent))
                        timelineViewModel?.setPixel(layerId: layerId, x: pixelX, y: pixelY, value: .transparent)
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
            timelineViewModel?.pixelStateManager?.syncToTimeline()
        }

        clearSelection()
    }

    var hasClipboard: Bool {
        return state.clipboard != nil
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

        if nearLeft && nearTop { return .topLeft }
        if nearRight && nearTop { return .topRight }
        if nearLeft && nearBottom { return .bottomLeft }
        if nearRight && nearBottom { return .bottomRight }

        if nearTop && px >= rect.minX && px <= rect.maxX { return .top }
        if nearBottom && px >= rect.minX && px <= rect.maxX { return .bottom }
        if nearLeft && py >= rect.minY && py <= rect.maxY { return .left }
        if nearRight && py >= rect.minY && py <= rect.maxY { return .right }

        return nil
    }

    // MARK: - Freeform Selection

    private func updateFreeformPath(x: Int, y: Int) {
        guard let canvas = canvasViewModel else { return }

        freeformSelector.updatePath(
            path: &freeformPath,
            lastPoint: &state.lastDrawPoint,
            currentX: x,
            currentY: y,
            canvasWidth: canvas.canvas.width,
            canvasHeight: canvas.canvas.height
        )

        if let bbox = freeformSelector.calculateBoundingBox(from: freeformPath) {
            selectionRect = bbox
        }
    }

    private func closeFreeformPath() {
        guard let canvas = canvasViewModel else { return }

        freeformSelector.closePath(
            path: &freeformPath,
            canvasWidth: canvas.canvas.width,
            canvasHeight: canvas.canvas.height
        )

        if let bbox = freeformSelector.calculateBoundingBox(from: freeformPath) {
            selectionRect = bbox
        }
    }
}
