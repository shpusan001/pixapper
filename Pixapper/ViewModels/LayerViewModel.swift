//
//  LayerViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

@MainActor
class LayerViewModel: ObservableObject {
    @Published var layers: [Layer]
    @Published var selectedLayerIndex: Int = 0

    private let canvasWidth: Int
    private let canvasHeight: Int

    init(width: Int, height: Int) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.layers = [Layer(name: "Layer 1", width: width, height: height)]
    }

    func addLayer() {
        let newLayer = Layer(name: "Layer \(layers.count + 1)", width: canvasWidth, height: canvasHeight)
        layers.append(newLayer)
        selectedLayerIndex = layers.count - 1
    }

    func deleteLayer(at index: Int) {
        guard layers.count > 1 && index < layers.count else { return }
        layers.remove(at: index)
        if selectedLayerIndex >= layers.count {
            selectedLayerIndex = layers.count - 1
        }
    }

    func duplicateLayer(at index: Int) {
        guard index < layers.count else { return }
        let duplicatedLayer = layers[index].duplicate(newName: "\(layers[index].name) Copy")
        layers.insert(duplicatedLayer, at: index + 1)
        selectedLayerIndex = index + 1
    }

    func renameLayer(at index: Int, to newName: String) {
        guard index < layers.count else { return }
        layers[index].name = newName
    }

    func moveLayer(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
        // Update selected index after move
        if let sourceIndex = source.first {
            if sourceIndex < destination {
                selectedLayerIndex = destination - 1
            } else {
                selectedLayerIndex = destination
            }
        }
    }

    func toggleVisibility(at index: Int) {
        guard index < layers.count else { return }
        layers[index].isVisible.toggle()
    }

    func setOpacity(at index: Int, opacity: Double) {
        guard index < layers.count else { return }
        layers[index].opacity = opacity
    }
}
