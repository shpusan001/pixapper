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
}
