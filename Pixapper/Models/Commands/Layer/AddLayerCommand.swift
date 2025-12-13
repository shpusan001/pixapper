//
//  AddLayerCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 레이어 추가 Command
class AddLayerCommand: Command {
    private weak var layerViewModel: LayerViewModel?
    private var addedLayerIndex: Int?
    private var addedLayer: Layer?

    var description: String {
        "Add layer"
    }

    init(layerViewModel: LayerViewModel) {
        self.layerViewModel = layerViewModel
    }

    func execute() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.addLayer()
        let index = layerViewModel.selectedLayerIndex
        addedLayerIndex = index
        if index < layerViewModel.layers.count {
            addedLayer = layerViewModel.layers[index]
        }
    }

    func undo() {
        guard let layerViewModel = layerViewModel,
              let index = addedLayerIndex,
              index < layerViewModel.layers.count else {
            return
        }
        layerViewModel.deleteLayer(at: index)
    }
}
