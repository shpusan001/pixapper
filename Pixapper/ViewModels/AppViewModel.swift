//
//  AppViewModel.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI
import Combine

/// 통합 앱 ViewModel - 모든 데이터를 중앙에서 관리
@MainActor
class AppViewModel: ObservableObject {
    // MARK: - 프로젝트 상태
    @Published private(set) var currentFileURL: URL?
    @Published private(set) var isDirty: Bool = false
    @Published var errorMessage: String?
    @Published var showingError: Bool = false

    // MARK: - ViewModels (내부 관리)
    let colorManager: ColorManager
    let layerViewModel: LayerViewModel
    let timelineViewModel: TimelineViewModel
    let canvasViewModel: CanvasViewModel
    let toolSettingsManager: ToolSettingsManager
    let commandManager: CommandManager

    private var cancellables = Set<AnyCancellable>()

    init(width: Int = 32, height: Int = 32) {
        // ViewModels 초기화 (기존 ContentView와 동일)
        let colorMgr = ColorManager()
        let layerVM = LayerViewModel(width: width, height: height)
        let cmdManager = CommandManager()
        let toolManager = ToolSettingsManager(colorManager: colorMgr)

        let canvasVM = CanvasViewModel(
            width: width,
            height: height,
            layerViewModel: layerVM,
            commandManager: cmdManager,
            toolSettingsManager: toolManager
        )

        let timelineVM = TimelineViewModel(
            width: width,
            height: height,
            layerViewModel: layerVM
        )

        self.colorManager = colorMgr
        self.layerViewModel = layerVM
        self.commandManager = cmdManager
        self.toolSettingsManager = toolManager
        self.canvasViewModel = canvasVM
        self.timelineViewModel = timelineVM

        // Canvas → Timeline 연결
        canvasVM.setTimelineViewModel(timelineVM)

        // 초기 프레임 로드
        timelineVM.loadFrame(at: 0)

        // 변경 추적 설정
        setupDirtyTracking()
    }

    // MARK: - 변경 추적
    private func setupDirtyTracking() {
        // 모든 변경사항을 하나의 Publisher로 통합
        Publishers.Merge4(
            layerViewModel.$layers.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            timelineViewModel.$totalFrames.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            timelineViewModel.$currentFrameIndex.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            commandManager.$undoStack.dropFirst().map { _ in () }.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            self?.markDirty()
        }
        .store(in: &cancellables)
    }

    private func markDirty() {
        Task { @MainActor in
            isDirty = true
        }
    }

    private func markClean() {
        isDirty = false
    }

    // MARK: - 프로젝트 관리

    /// 새 프로젝트 생성
    func newProject(width: Int = 32, height: Int = 32) {
        // 기존 ViewModel 재사용하여 리셋
        let emptyLayer = Layer(name: "Layer 1", width: width, height: height)
        layerViewModel.layers = [emptyLayer]
        layerViewModel.selectedLayerIndex = 0

        timelineViewModel.totalFrames = 1
        timelineViewModel.currentFrameIndex = 0
        timelineViewModel.settings = AnimationSettings()
        timelineViewModel.canvasWidth = width
        timelineViewModel.canvasHeight = height

        canvasViewModel.canvas = PixelCanvas(width: width, height: height)
        canvasViewModel.zoomLevel = 400.0

        toolSettingsManager.resetToDefaults()
        commandManager.clear()

        // PixelStateManager 재초기화
        timelineViewModel.pixelStateManager = PixelStateManager(
            canvasWidth: width,
            canvasHeight: height,
            layerViewModel: layerViewModel
        )
        layerViewModel.pixelStateManager = timelineViewModel.pixelStateManager

        timelineViewModel.loadFrame(at: 0)

        currentFileURL = nil
        markClean()
    }

    /// 프로젝트를 파일로 저장
    @discardableResult
    func saveProject(to url: URL? = nil) -> Bool {
        do {
            let document = createProjectDocument()
            if let savedURL = try ProjectManager.shared.save(document: document, to: url ?? currentFileURL) {
                currentFileURL = savedURL
                markClean()
                return true
            }
            return false
        } catch {
            errorMessage = "Failed to save project: \(error.localizedDescription)"
            showingError = true
            print("Failed to save project: \(error)")
            return false
        }
    }

    /// 프로젝트를 파일에서 불러오기
    @discardableResult
    func loadProject(from url: URL? = nil) -> Bool {
        do {
            guard let document = try ProjectManager.shared.load(from: url) else {
                return false  // 사용자가 취소함
            }

            applyProjectDocument(document)
            currentFileURL = url
            markClean()
            return true
        } catch {
            errorMessage = "Failed to load project: \(error.localizedDescription)"
            showingError = true
            print("Failed to load project: \(error)")
            return false
        }
    }

    // MARK: - ProjectDocument 변환

    /// 현재 상태에서 ProjectDocument 생성
    private func createProjectDocument() -> ProjectDocument {
        let serializableLayers = layerViewModel.layers.map { SerializableLayer(from: $0) }

        let timelineState = SerializableTimelineState(
            from: timelineViewModel.settings,
            totalFrames: timelineViewModel.totalFrames,
            currentFrameIndex: timelineViewModel.currentFrameIndex
        )

        let toolSettings = SerializableToolSettings(from: toolSettingsManager)

        // 현재 색상 팔레트 및 Primary/Secondary 색상 저장
        // PixelStateManager의 currentPalette 사용 (팔레트 시스템)
        let colorPalette = timelineViewModel.pixelStateManager.currentPalette.toSerializableColors()
        let primaryColor = SerializableColor(from: colorManager.primaryColor)
        let secondaryColor = SerializableColor(from: colorManager.secondaryColor)

        return ProjectDocument(
            metadata: ProjectMetadata(),
            canvasWidth: canvasViewModel.canvas.width,
            canvasHeight: canvasViewModel.canvas.height,
            layers: serializableLayers,
            selectedLayerIndex: layerViewModel.selectedLayerIndex,
            timeline: timelineState,
            toolSettings: toolSettings,
            zoomLevel: canvasViewModel.zoomLevel,
            colorPalette: colorPalette,
            primaryColor: primaryColor,
            secondaryColor: secondaryColor,
            canvasBackgroundMode: canvasViewModel.backgroundMode.rawValue,
            showGrid: canvasViewModel.showGrid
        )
    }

    /// ProjectDocument를 현재 상태에 적용
    private func applyProjectDocument(_ document: ProjectDocument) {
        let width = document.canvasWidth
        let height = document.canvasHeight

        // 레이어 복원
        let restoredLayers = document.layers.map { $0.toLayer(width: width, height: height) }
        layerViewModel.layers = restoredLayers
        layerViewModel.selectedLayerIndex = min(document.selectedLayerIndex, restoredLayers.count - 1)

        // 타임라인 복원
        timelineViewModel.totalFrames = document.timeline.totalFrames
        timelineViewModel.currentFrameIndex = min(document.timeline.currentFrameIndex, document.timeline.totalFrames - 1)
        timelineViewModel.settings = document.timeline.toAnimationSettings()

        // 캔버스 크기 및 설정 복원
        canvasViewModel.canvas.width = width
        canvasViewModel.canvas.height = height
        canvasViewModel.canvas.layers = restoredLayers
        canvasViewModel.zoomLevel = document.zoomLevel

        // 캔버스 배경 모드 복원 (이제 항상 존재)
        if let backgroundMode = CanvasBackgroundMode(rawValue: document.canvasBackgroundMode) {
            canvasViewModel.backgroundMode = backgroundMode
        }

        // 그리드 표시 복원 (이제 항상 존재)
        canvasViewModel.showGrid = document.showGrid

        // 툴 설정 복원
        document.toolSettings.applyTo(manager: toolSettingsManager)

        // 색상 팔레트 복원 - PaletteManager에 적용
        let loadedPalette = ColorPalette.fromSerializableColors(document.colorPalette, name: "Project Palette")
        timelineViewModel.pixelStateManager.paletteManager.currentPalette = loadedPalette

        // Primary/Secondary 색상 복원 (이제 항상 존재)
        colorManager.primaryColor = document.primaryColor.toColor()
        colorManager.secondaryColor = document.secondaryColor.toColor()

        // 현재 프레임 로드
        timelineViewModel.loadFrame(at: timelineViewModel.currentFrameIndex)

        // Undo/Redo 스택 초기화
        commandManager.clear()
    }
}
