//
//  RenameLayerCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 레이어 이름 변경 Command
class RenameLayerCommand: Command {
    private weak var layerViewModel: LayerViewModel?
    private let layerIndex: Int
    private let oldName: String
    private let newName: String

    var description: String {
        "Rename layer \(layerIndex) from '\(oldName)' to '\(newName)'"
    }

    init(layerViewModel: LayerViewModel, index: Int, oldName: String, newName: String) {
        self.layerViewModel = layerViewModel
        self.layerIndex = index
        self.oldName = oldName
        self.newName = newName
    }

    func execute() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.renameLayer(at: layerIndex, to: newName)
    }

    func undo() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.renameLayer(at: layerIndex, to: oldName)
    }
}
