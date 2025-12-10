//
//  LayerCommand.swift
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
        addedLayerIndex = layerViewModel.selectedLayerIndex
        if addedLayerIndex! < layerViewModel.layers.count {
            addedLayer = layerViewModel.layers[addedLayerIndex!]
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

/// 레이어 블렌드 모드 변경 Command
class SetLayerBlendModeCommand: Command {
    private weak var layerViewModel: LayerViewModel?
    private let layerIndex: Int
    private let oldMode: BlendMode
    private let newMode: BlendMode

    var description: String {
        "Set layer \(layerIndex) blend mode to \(newMode.rawValue)"
    }

    init(layerViewModel: LayerViewModel, index: Int, oldMode: BlendMode, newMode: BlendMode) {
        self.layerViewModel = layerViewModel
        self.layerIndex = index
        self.oldMode = oldMode
        self.newMode = newMode
    }

    func execute() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.setBlendMode(at: layerIndex, mode: newMode)
    }

    func undo() {
        guard let layerViewModel = layerViewModel else { return }
        layerViewModel.setBlendMode(at: layerIndex, mode: oldMode)
    }
}
