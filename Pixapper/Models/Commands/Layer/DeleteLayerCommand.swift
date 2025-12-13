//
//  DeleteLayerCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 레이어 삭제 Command
class DeleteLayerCommand: Command {
    private weak var layerViewModel: LayerViewModel?
    private let deletedIndex: Int
    private var deletedLayer: Layer?
    private var previousSelectedIndex: Int

    var description: String {
        "Delete layer at index \(deletedIndex)"
    }

    init(layerViewModel: LayerViewModel, index: Int) {
        self.layerViewModel = layerViewModel
        self.deletedIndex = index
        self.previousSelectedIndex = layerViewModel.selectedLayerIndex
        if index < layerViewModel.layers.count {
            self.deletedLayer = layerViewModel.layers[index]
        }
    }

    func execute() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.deleteLayer(at: deletedIndex)
    }

    func undo() {
        guard let layerViewModel = layerViewModel,
              let layer = deletedLayer else {
            return
        }
        layerViewModel.layers.insert(layer, at: deletedIndex)
        layerViewModel.selectedLayerIndex = previousSelectedIndex
    }
}
