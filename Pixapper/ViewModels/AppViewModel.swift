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

    // MARK: - ViewModels (내부 관리)
    let layerViewModel: LayerViewModel
    let timelineViewModel: TimelineViewModel
    let canvasViewModel: CanvasViewModel
    let toolSettingsManager: ToolSettingsManager
    let commandManager: CommandManager

    private var cancellables = Set<AnyCancellable>()

    init(width: Int = 32, height: Int = 32) {
        // ViewModels 초기화 (기존 ContentView와 동일)
        let layerVM = LayerViewModel(width: width, height: height)
        let cmdManager = CommandManager()
        let toolManager = ToolSettingsManager()

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
        // 레이어 변경 추적
        layerViewModel.$layers
            .dropFirst()
            .sink { [weak self] _ in
                self?.markDirty()
            }
            .store(in: &cancellables)

        // 타임라인 변경 추적
        timelineViewModel.$totalFrames
            .dropFirst()
            .sink { [weak self] _ in
                self?.markDirty()
            }
            .store(in: &cancellables)

        timelineViewModel.$currentFrameIndex
            .dropFirst()
            .sink { [weak self] _ in
                self?.markDirty()
            }
            .store(in: &cancellables)

        // 커맨드 실행 시 dirty 표시
        commandManager.$undoStack
            .dropFirst()
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
        // 기존 내용 초기화
        let newLayerVM = LayerViewModel(width: width, height: height)
        let newTimelineVM = TimelineViewModel(width: width, height: height, layerViewModel: newLayerVM)

        // 데이터 복사
        layerViewModel.layers = newLayerVM.layers
        layerViewModel.selectedLayerIndex = 0

        timelineViewModel.totalFrames = 1
        timelineViewModel.currentFrameIndex = 0
        timelineViewModel.settings = AnimationSettings()

        canvasViewModel.canvas = PixelCanvas(width: width, height: height)
        canvasViewModel.zoomLevel = 400.0

        toolSettingsManager.resetToDefaults()
        commandManager.clear()

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

        return ProjectDocument(
            metadata: ProjectMetadata(),
            canvasWidth: canvasViewModel.canvas.width,
            canvasHeight: canvasViewModel.canvas.height,
            layers: serializableLayers,
            selectedLayerIndex: layerViewModel.selectedLayerIndex,
            timeline: timelineState,
            toolSettings: toolSettings,
            zoomLevel: canvasViewModel.zoomLevel
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

        // 캔버스 크기 복원
        canvasViewModel.canvas.width = width
        canvasViewModel.canvas.height = height
        canvasViewModel.canvas.layers = restoredLayers
        canvasViewModel.zoomLevel = document.zoomLevel

        // 툴 설정 복원
        document.toolSettings.applyTo(manager: toolSettingsManager)

        // 현재 프레임 로드
        timelineViewModel.loadFrame(at: timelineViewModel.currentFrameIndex)

        // Undo/Redo 스택 초기화
        commandManager.clear()
    }
}
