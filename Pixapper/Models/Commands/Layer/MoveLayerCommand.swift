//
//  MoveLayerCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 레이어 이동(순서 변경) Command
class MoveLayerCommand: Command {
    private weak var layerViewModel: LayerViewModel?
    private let sourceIndices: IndexSet
    private let destination: Int
    private var originalOrder: [Layer]

    var description: String {
        "Move layer from \(sourceIndices) to \(destination)"
    }

    init(layerViewModel: LayerViewModel, from source: IndexSet, to destination: Int) {
        self.layerViewModel = layerViewModel
        self.sourceIndices = source
        self.destination = destination
        self.originalOrder = layerViewModel.layers
    }

    func execute() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.moveLayer(from: sourceIndices, to: destination)
    }

    func undo() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.layers = originalOrder
        // 선택 인덱스 복원
        if let sourceIndex = sourceIndices.first, sourceIndex < originalOrder.count {
            layerViewModel.selectedLayerIndex = sourceIndex
        }
    }
}
