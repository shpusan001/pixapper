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

/// 텍스트 편집 상태
struct TextEditState {
    var rect: CGRect  // 텍스트 박스 영역 (픽셀 좌표)
    var isEditing: Bool = false
    var text: String = ""  // 텍스트 내용

    // 렌더링된 픽셀
    var previewPixels: [(x: Int, y: Int, color: Color)] = []

    // 커서 상태
    var cursorPosition: Int = 0  // 텍스트 내 커서 위치
    var cursorVisible: Bool = true  // 깜박임 상태
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
    @Published var brushPreviewPositions: [(x: Int, y: Int)] = []  // Mirror 툴용 다중 프리뷰
    @Published var shiftPressed: Bool = false {
        didSet {
            _selectionTool?.setShiftPressed(shiftPressed)
        }
    }
    @Published var textEditState: TextEditState? = nil  // 텍스트 편집 상태
    @Published var textBoxHoveredHandle: TextBoxHandle? = nil  // 텍스트 박스 호버 핸들

    // MARK: - View Toggle Methods

    func toggleGrid() {
        showGrid.toggle()
    }

    func toggleBackground() {
        objectWillChange.send()
        backgroundMode = backgroundMode == .checkerboard ? .white : .checkerboard
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
    private var mirrorTool: MirrorTool!
    private var ditheringTool: DitheringTool!
    private var textTool: TextTool!

    // MARK: - Internal State
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Selection Properties (@Published로 실시간 UI 업데이트)
    /// SelectionTool이 이 프로퍼티들을 직접 수정하여 UI를 업데이트합니다
    @Published var selectionRect: CGRect?
    @Published var selectionPixels: PixelGrid?
    @Published var selectionOffset: CGPoint = .zero
    @Published var isFloatingSelection: Bool = false
    @Published var originalPixels: PixelGrid?
    @Published var originalRect: CGRect?
    @Published var selectionMode: SelectionTool.SelectionMode = .idle
    @Published var hoveredHandle: SelectionTool.ResizeHandle?
    @Published var freeformPath: [(x: Int, y: Int)] = []
    @Published var freeformMask: [[Bool]]?

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

        // 프레임 변경 시 텍스트 자동 커밋 (표준 UX)
        timeline.$currentFrameIndex
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.textEditState != nil {
                    self.commitText()
                }
            }
            .store(in: &cancellables)
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

        self.mirrorTool = MirrorTool(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            commandManager: commandManager,
            toolSettingsManager: toolSettingsManager,
            timelineViewModel: timelineViewModel
        )

        self.ditheringTool = DitheringTool(
            canvasViewModel: self,
            layerViewModel: layerViewModel,
            commandManager: commandManager,
            toolSettingsManager: toolSettingsManager,
            timelineViewModel: timelineViewModel
        )

        self.textTool = TextTool(
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

                // 텍스트 입력 중이면 자동 커밋 (표준 UX)
                if newTool != .text && self.textEditState != nil {
                    self.commitText()
                }

                if newTool != .selection {
                    if self.isFloatingSelection {
                        self.commitSelection()
                    } else if self.selectionRect != nil {
                        self.clearSelection()
                    }
                }
            }
            .store(in: &cancellables)

        // 레이어 변경 시 텍스트 자동 커밋 (표준 UX)
        layerViewModel.$selectedLayerIndex
            .dropFirst()
            .sink { [weak self] _ in
                guard let self = self else { return }
                if self.textEditState != nil {
                    self.commitText()
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
        case .mirror:
            return mirrorTool
        case .dithering:
            return ditheringTool
        case .text:
            return textTool
        }
    }

    // MARK: - Text Operations (delegated to TextTool)

    func updateTextPreview() {
        textTool.updateTextPreview()
    }

    func commitText() {
        textTool.commitText()
    }

    func cancelText() {
        textTool.cancelText()
    }

    // MARK: - Selection Operations (delegated to SelectionTool)

    func captureSelection() {
        _selectionTool.captureSelection()
    }

    func cancelSelection() {
        _selectionTool.cancelSelection()
    }

    func clearSelection() {
        _selectionTool.clearSelection()
    }

    func restoreSelectionState(
        rect: CGRect?,
        pixels: PixelGrid?,
        originalPixels: PixelGrid?,
        originalRect: CGRect?,
        isFloating: Bool,
        freeformMask: [[Bool]]? = nil
    ) {
        _selectionTool.restoreSelectionState(
            rect: rect,
            pixels: pixels,
            originalPixels: originalPixels,
            originalRect: originalRect,
            isFloating: isFloating,
            freeformMask: freeformMask
        )
    }

    func setFloatingSelection(
        rect: CGRect,
        pixels: PixelGrid,
        originalPixels: PixelGrid,
        originalRect: CGRect,
        freeformMask: [[Bool]]?
    ) {
        _selectionTool.restoreSelectionState(
            rect: rect,
            pixels: pixels,
            originalPixels: originalPixels,
            originalRect: originalRect,
            isFloating: true,
            freeformMask: freeformMask
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

    func applyTransformFromCommand(pixels: PixelGrid, rect: CGRect) {
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

    // MARK: - Undo/Redo

    func performUndo() {
        commandManager.undo()

        // Undo 후 selection tool이 아니면 선택 영역 정리
        if toolSettingsManager.selectedTool != .selection {
            if isFloatingSelection {
                // Floating selection은 레이어에 커밋
                commitSelection()
            } else {
                // 일반 selection은 그냥 clear
                clearSelection()
            }
        }
    }

    func performRedo() {
        commandManager.redo()

        // Redo 후 selection tool이 아니면 선택 영역 정리
        if toolSettingsManager.selectedTool != .selection {
            if isFloatingSelection {
                // Floating selection은 레이어에 커밋
                commitSelection()
            } else {
                // 일반 selection은 그냥 clear
                clearSelection()
            }
        }
    }

    // MARK: - Helper Methods

    /// 두 색상의 RGB 정밀 비교
    func colorsEqual(_ c1: Color?, _ c2: Color?) -> Bool {
        return Color.areEqual(c1, c2)
    }

    /// PixelChange 계산 헬퍼 (Commands에서 사용)
    func calculatePixelChanges(
        pixels: PixelGrid,
        origPixels: PixelGrid?,
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
                if pixelsToRemove[y][x] != .transparent {
                    let pixelX = origStartX + x
                    let pixelY = origStartY + y
                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldValue = layerViewModel.layers[layerIndex].getPixel(x: pixelX, y: pixelY) ?? .transparent
                        oldPixels.append(PixelChange(x: pixelX, y: pixelY, value: oldValue))
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, value: .transparent))
                    }
                }
            }
        }

        // 2. 새 위치에 색칠된 픽셀만 배치
        let startX = Int(newRect.minX)
        let startY = Int(newRect.minY)

        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                let pixelValue = pixels[y][x]
                if pixelValue != .transparent {
                    let pixelX = startX + x
                    let pixelY = startY + y
                    if pixelX >= 0 && pixelX < canvas.width && pixelY >= 0 && pixelY < canvas.height {
                        let oldValue = layerViewModel.layers[layerIndex].getPixel(x: pixelX, y: pixelY) ?? .transparent
                        if !oldPixels.contains(where: { $0.x == pixelX && $0.y == pixelY }) {
                            oldPixels.append(PixelChange(x: pixelX, y: pixelY, value: oldValue))
                        }
                        newPixels.append(PixelChange(x: pixelX, y: pixelY, value: pixelValue))
                    }
                }
            }
        }

        return (oldPixels, newPixels)
    }
}
