//
//  SetLayerOpacityCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 레이어 불투명도 변경 Command
class SetLayerOpacityCommand: Command {
    private weak var layerViewModel: LayerViewModel?
    private let layerIndex: Int
    private let oldOpacity: Double
    private let newOpacity: Double

    var description: String {
        "Set layer \(layerIndex) opacity to \(newOpacity)"
    }

    init(layerViewModel: LayerViewModel, index: Int, oldOpacity: Double, newOpacity: Double) {
        self.layerViewModel = layerViewModel
        self.layerIndex = index
        self.oldOpacity = oldOpacity
        self.newOpacity = newOpacity
    }

    func execute() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.setOpacity(at: layerIndex, opacity: newOpacity)
    }

    func undo() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.setOpacity(at: layerIndex, opacity: oldOpacity)
    }
}
