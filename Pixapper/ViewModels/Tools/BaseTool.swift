//
//  BaseTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI

/// 모든 Tool 클래스의 공통 기반 클래스
/// - Note: 중복 코드를 제거하고 일관된 의존성 관리를 제공합니다
@MainActor
class BaseTool {
    // MARK: - Dependencies
    weak var canvasViewModel: CanvasViewModel?
    let layerViewModel: LayerViewModel
    let commandManager: CommandManager
    let toolSettingsManager: ToolSettingsManager
    weak var timelineViewModel: TimelineViewModel?

    // MARK: - Drawing State

    /// 스트로크 그리기 상태 (그리기 도구용)
    struct DrawingState {
        var currentStrokePixels: [PixelChange] = []
        var oldStrokePixels: [PixelChange] = []
        var drawnPixelsInStroke: Set<PixelPoint> = []

        mutating func reset() {
            currentStrokePixels = []
            oldStrokePixels = []
            drawnPixelsInStroke = []
        }
    }

    var drawingState = DrawingState()

    // MARK: - Initialization

    init(
        canvasViewModel: CanvasViewModel,
        layerViewModel: LayerViewModel,
        commandManager: CommandManager,
        toolSettingsManager: ToolSettingsManager,
        timelineViewModel: TimelineViewModel?
    ) {
        self.canvasViewModel = canvasViewModel
        self.layerViewModel = layerViewModel
        self.commandManager = commandManager
        self.toolSettingsManager = toolSettingsManager
        self.timelineViewModel = timelineViewModel
    }

    nonisolated deinit {
        // Subclasses can override for cleanup
    }

    // MARK: - Helper Properties

    /// 현재 선택된 레이어의 인덱스
    var currentLayerIndex: Int {
        layerViewModel.selectedLayerIndex
    }

    /// 현재 선택된 레이어의 ID
    var currentLayerId: UUID? {
        guard currentLayerIndex < layerViewModel.layers.count else { return nil }
        return layerViewModel.layers[currentLayerIndex].id
    }

    // MARK: - Common Methods

    /// 스트로크 시작 - DrawingState 초기화
    func beginStroke() {
        drawingState.reset()
    }

    /// 스트로크 완료 - Command 생성 및 타임라인 동기화
    func finishStroke() {
        guard !drawingState.currentStrokePixels.isEmpty,
              let layerId = currentLayerId else {
            drawingState.reset()
            return
        }

        let command = DrawCommand(
            timelineViewModel: timelineViewModel,
            layerId: layerId,
            oldPixels: drawingState.oldStrokePixels,
            newPixels: drawingState.currentStrokePixels
        )
        commandManager.addExecutedCommand(command)
        drawingState.reset()

        // 타임라인에 즉시 동기화
        timelineViewModel?.pixelStateManager?.syncToTimeline()
    }
}

/// 픽셀 좌표를 나타내는 Hashable 구조체
struct PixelPoint: Hashable {
    let x: Int
    let y: Int

    init(_ x: Int, _ y: Int) {
        self.x = x
        self.y = y
    }
}
