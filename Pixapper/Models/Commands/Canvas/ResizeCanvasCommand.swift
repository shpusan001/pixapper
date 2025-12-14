//
//  ResizeCanvasCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import Foundation

/// 캔버스 크기 변경 Command
class ResizeCanvasCommand: Command {
    private weak var canvasViewModel: CanvasViewModel?
    private let oldWidth: Int
    private let oldHeight: Int
    private let newWidth: Int
    private let newHeight: Int

    // 이전 상태 저장 (모든 레이어의 타임라인)
    private var oldLayersState: [LayerState] = []
    private var newLayersState: [LayerState] = []

    struct LayerState {
        let layerId: UUID
        let timeline: LayerTimeline
    }

    var description: String {
        "Resize Canvas \(oldWidth)×\(oldHeight) → \(newWidth)×\(newHeight)"
    }

    init(canvasViewModel: CanvasViewModel, oldWidth: Int, oldHeight: Int, newWidth: Int, newHeight: Int) {
        self.canvasViewModel = canvasViewModel
        self.oldWidth = oldWidth
        self.oldHeight = oldHeight
        self.newWidth = newWidth
        self.newHeight = newHeight
    }

    func execute() {
        guard let vm = canvasViewModel else { return }

        // 현재 상태 저장 (실행 전)
        if oldLayersState.isEmpty {
            oldLayersState = vm.layerViewModel.layers.map { layer in
                LayerState(layerId: layer.id, timeline: layer.timeline)
            }
        }

        // 리사이즈 실행
        vm.resizeCanvas(width: newWidth, height: newHeight)

        // 새 상태 저장 (실행 후)
        if newLayersState.isEmpty {
            newLayersState = vm.layerViewModel.layers.map { layer in
                LayerState(layerId: layer.id, timeline: layer.timeline)
            }
        }
    }

    func undo() {
        guard let vm = canvasViewModel else { return }

        // 선택 영역이 있으면 커밋
        if vm.isFloatingSelection {
            vm.commitSelection()
        } else {
            vm.clearSelection()
        }

        // 캔버스 크기 복원
        vm.canvas.width = oldWidth
        vm.canvas.height = oldHeight

        // 모든 레이어 타임라인 복원
        for (index, layerState) in oldLayersState.enumerated() {
            if index < vm.layerViewModel.layers.count {
                vm.layerViewModel.layers[index].timeline = layerState.timeline
            }
        }

        // 현재 프레임 다시 로드
        if let timeline = vm.timelineViewModel {
            timeline.loadFrame(at: timeline.currentFrameIndex)
        }
    }
}
