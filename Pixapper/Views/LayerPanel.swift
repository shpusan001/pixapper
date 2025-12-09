//
//  LayerPanel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct LayerPanel: View {
    @ObservedObject var viewModel: LayerViewModel
    @State private var editingLayerIndex: Int?
    @State private var editingName: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Layers")
                    .font(.headline)
                Spacer()
            }
            .padding(12)

            Divider()

            // Layer list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(Array(viewModel.layers.enumerated().reversed()), id: \.element.id) { index, layer in
                        let actualIndex = viewModel.layers.count - 1 - index
                        LayerRow(
                            layer: layer,
                            isSelected: actualIndex == viewModel.selectedLayerIndex,
                            isEditing: editingLayerIndex == actualIndex,
                            editingName: $editingName,
                            onSelect: {
                                viewModel.selectedLayerIndex = actualIndex
                            },
                            onToggleVisibility: {
                                viewModel.toggleVisibility(at: actualIndex)
                            },
                            onStartEditing: {
                                editingLayerIndex = actualIndex
                                editingName = layer.name
                            },
                            onEndEditing: {
                                if !editingName.isEmpty {
                                    viewModel.renameLayer(at: actualIndex, to: editingName)
                                }
                                editingLayerIndex = nil
                            },
                            onDelete: {
                                viewModel.deleteLayer(at: actualIndex)
                            },
                            onDuplicate: {
                                viewModel.duplicateLayer(at: actualIndex)
                            }
                        )
                    }
                }
                .padding(8)
            }

            Divider()

            // Selected layer controls
            if viewModel.selectedLayerIndex < viewModel.layers.count {
                VStack(alignment: .leading, spacing: 12) {
                    // Opacity control
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Opacity")
                                .font(.callout)
                            Spacer()
                            Text("\(Int(viewModel.layers[viewModel.selectedLayerIndex].opacity * 100))%")
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        Slider(
                            value: Binding(
                                get: { viewModel.layers[viewModel.selectedLayerIndex].opacity },
                                set: { viewModel.setOpacity(at: viewModel.selectedLayerIndex, opacity: $0) }
                            ),
                            in: 0...1
                        )
                    }

                    // Blend mode picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Blend Mode")
                            .font(.callout)
                        Picker("Blend Mode", selection: Binding(
                            get: { viewModel.layers[viewModel.selectedLayerIndex].blendMode },
                            set: { viewModel.setBlendMode(at: viewModel.selectedLayerIndex, mode: $0) }
                        )) {
                            ForEach(BlendMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .labelsHidden()
                    }
                }
                .padding(12)
            }

            Divider()

            // Layer operations
            HStack(spacing: 12) {
                Button(action: { viewModel.addLayer() }) {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Add Layer")

                Button(action: {
                    if viewModel.layers.count > 1 {
                        viewModel.deleteLayer(at: viewModel.selectedLayerIndex)
                    }
                }) {
                    Image(systemName: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.layers.count <= 1)
                .help("Delete Layer")

                Button(action: {
                    viewModel.duplicateLayer(at: viewModel.selectedLayerIndex)
                }) {
                    Image(systemName: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Duplicate Layer")
            }
            .padding(12)
        }
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct LayerRow: View {
    let layer: Layer
    let isSelected: Bool
    let isEditing: Bool
    @Binding var editingName: String
    let onSelect: () -> Void
    let onToggleVisibility: () -> Void
    let onStartEditing: () -> Void
    let onEndEditing: () -> Void
    let onDelete: () -> Void
    let onDuplicate: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Visibility toggle
            Button(action: onToggleVisibility) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 14))
                    .frame(width: 20, height: 20)
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            // Layer name
            if isEditing {
                TextField("Layer name", text: $editingName, onCommit: onEndEditing)
                    .textFieldStyle(.roundedBorder)
                    .font(.callout)
            } else {
                Text(layer.name)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        onStartEditing()
                    }
            }
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isEditing {
                onSelect()
            }
        }
        .contextMenu {
            Button("Rename") { onStartEditing() }
            Button("Duplicate") { onDuplicate() }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
