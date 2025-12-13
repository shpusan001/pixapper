//
//  CanvasViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

/// 캔버스 배경 모드
enum CanvasBackgroundMode: String, CaseIterable {
    case checkerboard = "Checkerboard"
    case white = "White"
}

@MainActor
class CanvasViewModel: ObservableObject {
    // MARK: - Canvas State
    @Published var canvas: PixelCanvas
    @Published var zoomLevel: Double = 400.0
    @Published var backgroundMode: CanvasBackgroundMode = .checkerboard
    @Published var showGrid: Bool = true
    @Published var shapePreview: [(x: Int, y: Int, color: Color)] = []
    @Published var brushPreviewPosition: (x: Int, y: Int)?
    @Published var shiftPressed: Bool = false {
        didSet {
            _selectionTool?.setShiftPressed(shiftPressed)
        }
    }

    // MARK: - Dependencies
    var layerViewModel: LayerViewModel
    var commandManager: CommandManager
    var toolSettingsManager: ToolSettingsManager
    weak var timelineViewModel: TimelineViewModel?

    // MARK: - Tools
    private var pencilEraserTool: PencilEraserTool!
    private var fillTool: FillTool!
    private var shapeTool: ShapeTool!
    private var _selectionTool: SelectionTool!

    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Selection Properties (@Published로 실시간 UI 업데이트)
    /// SelectionTool이 이 프로퍼티들을 직접 수정하여 UI를 업데이트합니다
    @Published var selectionRect: CGRect?
    @Published var selectionPixels: [[Color?]]?
    @Published var selectionOffset: CGPoint = .zero
    @Published var isFloatingSelection: Bool = false
    @Published var originalPixels: [[Color?]]?
    @Published var originalRect: CGRect?
    @Published var selectionMode: SelectionTool.SelectionMode = .idle
    @Published var hoveredHandle: SelectionTool.ResizeHandle?

    var isMovingSelection: Bool {
        if case .moving = selectionMode {
            return true
        }
        return false
    }

    // MARK: - Initialization

    init(
        width: Int = 32,
        height: Int = 32,
        layerViewModel: LayerViewModel,
        commandManager: CommandManager,
        toolSettingsManager: ToolSettingsManager
    ) {
        self.canvas = PixelCanvas(width: width, height: height)
        self.layerViewModel = layerViewModel
        self.commandManager = commandManager
        self.toolSettingsManager = toolSettingsManager

        // Initialize tools (timelineViewModel will be set later)
        setupTools(timelineViewModel: nil)

        // Setup bindings
        setupBindings()
    }

    func setTimelineViewModel(_ timeline: TimelineViewModel) {
        self.timelineViewModel = timeline

        // Recreate tools with timeline reference
        setupTools(timelineViewModel: timeline)
    }

    /// 도구들을 생성하거나 재생성합니다
    private func setupTools(timelineViewModel: TimelineViewModel?) {
        self._selectionTool = SelectionTool(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            commandManager: commandManager,
            toolSettingsManager: toolSettingsManager,
            timelineViewModel: timelineViewModel
        )

        self.pencilEraserTool = PencilEraserTool(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            commandManager: commandManager,
            toolSettingsManager: toolSettingsManager,
            timelineViewModel: timelineViewModel
        )

        self.fillTool = FillTool(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            commandManager: commandManager,
            toolSettingsManager: toolSettingsManager,
            timelineViewModel: timelineViewModel
        )

        self.shapeTool = ShapeTool(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            commandManager: commandManager,
            toolSettingsManager: toolSettingsManager,
            timelineViewModel: timelineViewModel
        )
    }

    private func setupBindings() {
        // Sync canvas layers with LayerViewModel
        layerViewModel.$layers
            .sink { [weak self] layers in
                self?.canvas.layers = layers
            }
            .store(in: &cancellables)

        // 도구 변경 시 선택 영역 처리
        toolSettingsManager.$selectedTool
            .dropFirst()
            .sink { [weak self] newTool in
                guard let self = self else { return }

                if newTool != .selection {
                    if self.isFloatingSelection {
                        self.commitSelection()
                    } else if self.selectionRect != nil {
                        self.clearSelection()
                    }
                }
            }
            .store(in: &cancellables)
    }

    var currentLayerIndex: Int {
        layerViewModel.selectedLayerIndex
    }

    // MARK: - Tool Event Handling

    func handleToolDown(x: Int, y: Int, altPressed: Bool = false) {
        // 선택 도구가 아닌 경우, 선택 영역이 있으면 먼저 처리
        if toolSettingsManager.selectedTool != .selection {
            if isFloatingSelection {
                commitSelection()
            } else if selectionRect != nil {
                clearSelection()
            }
        }

        let tool = getCurrentTool()
        tool.handleDown(x: x, y: y, altPressed: altPressed)
    }

    func handleToolDrag(x: Int, y: Int) {
        let tool = getCurrentTool()
        tool.handleDrag(x: x, y: y)
    }

    func handleToolUp(x: Int, y: Int) {
        let tool = getCurrentTool()
        tool.handleUp(x: x, y: y)
    }

    func updateHover(x: Int, y: Int) {
        let tool = getCurrentTool()
        tool.updateHover(x: x, y: y)
    }

    func clearHover() {
        let tool = getCurrentTool()
        tool.clearHover()
    }

    func handleOutsideClick() {
        let tool = getCurrentTool()
        tool.handleOutsideClick()
    }

    private func getCurrentTool() -> CanvasTool {
        switch toolSettingsManager.selectedTool {
        case .pencil, .eraser:
            return pencilEraserTool
        case .fill:
            return fillTool
        case .rectangle, .circle, .line:
            return shapeTool
        case .selection:
            return _selectionTool
        }
    }

    // MARK: - Selection Operations (delegated to SelectionTool)

    func captureSelection() {
        _selectionTool.captureSelection()
    }

    func clearSelection() {
        _selectionTool.clearSelection()
    }

    func restoreSelectionState(
        rect: CGRect?,
        pixels: [[Color?]]?,
        originalPixels: [[Color?]]?,
        originalRect: CGRect?,
        isFloating: Bool
    ) {
        _selectionTool.restoreSelectionState(
            rect: rect,
            pixels: pixels,
            originalPixels: originalPixels,
            originalRect: originalRect,
            isFloating: isFloating
        )
    }

    func commitSelection() {
        _selectionTool.commitSelection()
    }

    func checkInsideSelection(x: Int, y: Int) -> Bool {
        _selectionTool.checkInsideSelection(x: x, y: y)
    }

    // MARK: - Selection Transform (delegated to SelectionTool)

    func rotateSelectionCW() {
        _selectionTool.rotateSelectionCW()
    }

    func rotateSelectionCCW() {
        _selectionTool.rotateSelectionCCW()
    }

    func rotateSelection180() {
        _selectionTool.rotateSelection180()
    }

    func flipSelectionHorizontal() {
        _selectionTool.flipSelectionHorizontal()
    }

    func flipSelectionVertical() {
        _selectionTool.flipSelectionVertical()
    }

    func applyTransformFromCommand(pixels: [[Color?]], rect: CGRect) {
        _selectionTool.applyTransformFromCommand(pixels: pixels, rect: rect)
    }

    // MARK: - Selection Clipboard (delegated to SelectionTool)

    func copySelection() {
        _selectionTool.copySelection()
    }

    func cutSelection() {
        _selectionTool.cutSelection()
    }

    func pasteSelection() {
        _selectionTool.pasteSelection()
    }

    func deleteSelection() {
        _selectionTool.deleteSelection()
    }

    var hasClipboard: Bool {
        _selectionTool.hasClipboard
    }

    // MARK: - Canvas Resize

    func resizeCanvas(width: Int, height: Int) {
        // 선택 영역이 있으면 커밋
        if isFloatingSelection {
            commitSelection()
        } else {
            clearSelection()
        }

        // 새 캔버스 크기로 업데이트
        canvas.width = width
        canvas.height = height

        // 모든 레이어 크기 조정
        for index in layerViewModel.layers.indices {
            layerViewModel.layers[index].resizeCanvas(width: width, height: height)
        }

        // Timeline의 모든 프레임/키프레임 크기 조정
        timelineViewModel?.resizeAllFrames(width: width, height: height)

        // 현재 프레임 다시 로드
        if let timeline = timelineViewModel {
            timeline.loadFrame(at: timeline.currentFrameIndex)
        }
    }

    // MARK: - Helper Methods

    /// 두 색상의 RGB 정밀 비교
    func colorsEqual(_ c1: Color?, _ c2: Color?) -> Bool {
        if c1 == nil && c2 == nil {
            return true
        }
        guard let c1 = c1, let c2 = c2 else {
            return false
        }
        return c1.isEqual(to: c2, tolerance: Constants.Color.defaultTolerance)
    }

    /// PixelChange 계산 헬퍼 (Commands에서 사용)
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
}
