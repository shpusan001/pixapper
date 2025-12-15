//
//  TimelineLayerInfoView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI
import UniformTypeIdentifiers

/// 타임라인 레이어 정보 컬럼
/// - 드래그 핸들, Visibility, 이름, Opacity 표시 및 편집
struct TimelineLayerInfoView: View {
    let layer: Layer
    let layerIndex: Int
    let layerColumnWidth: CGFloat
    let cellSize: CGFloat

    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var commandManager: CommandManager

    @Binding var editingLayerIndex: Int?
    @Binding var editingLayerName: String
    @Binding var editingOpacityLayerIndex: Int?
    @Binding var opacityBeforeDrag: Double?
    @Binding var currentOpacity: Double
    @Binding var draggingLayerIndex: Int?

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: 14)

            // Visibility toggle
            Button(action: {
                viewModel.layerViewModel.toggleVisibility(at: layerIndex)
            }) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
                    .foregroundColor(layer.isVisible ? Constants.Theme.textPrimary : Constants.Theme.textDisabled)
            }
            .buttonStyle(.plain)

            // Layer name and opacity
            VStack(alignment: .leading, spacing: 1) {
                // Layer name (editable)
                if editingLayerIndex == layerIndex {
                    TextField("Name", text: $editingLayerName, onCommit: {
                        if !editingLayerName.isEmpty {
                            let oldName = layer.name
                            let command = RenameLayerCommand(layerViewModel: viewModel.layerViewModel, index: layerIndex, oldName: oldName, newName: editingLayerName)
                            commandManager.performCommand(command)
                        }
                        editingLayerIndex = nil
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Constants.Theme.textPrimary)
                } else {
                    Text(layer.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Constants.Theme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editingLayerIndex = layerIndex
                            editingLayerName = layer.name
                        }
                        .onTapGesture(count: 1) {
                            if editingLayerIndex == nil && editingOpacityLayerIndex == nil {
                                viewModel.layerViewModel.selectedLayerIndex = layerIndex
                            }
                        }
                }

                // Opacity control - interactive
                if editingOpacityLayerIndex == layerIndex {
                    HStack(spacing: 2) {
                        Slider(
                            value: Binding(
                                get: { currentOpacity },
                                set: { newValue in
                                    currentOpacity = newValue
                                    viewModel.layerViewModel.setOpacity(at: layerIndex, opacity: newValue)
                                }
                            ),
                            in: 0...1,
                            onEditingChanged: { isEditing in
                                if isEditing {
                                    opacityBeforeDrag = layer.opacity
                                } else {
                                    if let oldOpacity = opacityBeforeDrag {
                                        let newOpacity = currentOpacity
                                        if abs(oldOpacity - newOpacity) > 0.001 {
                                            let command = SetLayerOpacityCommand(
                                                layerViewModel: viewModel.layerViewModel,
                                                index: layerIndex,
                                                oldOpacity: oldOpacity,
                                                newOpacity: newOpacity
                                            )
                                            commandManager.addExecutedCommand(command)
                                        }
                                        opacityBeforeDrag = nil
                                    }
                                    editingOpacityLayerIndex = nil
                                }
                            }
                        )
                        .tint(Constants.Theme.accentBlue)
                        .frame(height: 12)
                    }
                } else {
                    // Percentage display (clickable to edit)
                    Text("\(Int(layer.opacity * 100))%")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Constants.Theme.textSecondary.opacity(0.7))
                        .frame(width: 28, alignment: .trailing)
                        .onTapGesture {
                            editingOpacityLayerIndex = layerIndex
                            currentOpacity = layer.opacity
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: layerColumnWidth, height: cellSize)
        .background(
            Group {
                if layerIndex == viewModel.layerViewModel.selectedLayerIndex {
                    Constants.Theme.accentBlue.opacity(0.2)
                } else if draggingLayerIndex == layerIndex {
                    Constants.Theme.accentBlue.opacity(0.3)
                } else {
                    Constants.Theme.panelBackground
                }
            }
        )
        .contentShape(Rectangle())
        .opacity(draggingLayerIndex == layerIndex ? 0.5 : 1.0)
        .onDrag {
            draggingLayerIndex = layerIndex
            return NSItemProvider(object: "\(layerIndex)" as NSString)
        }
        .onDrop(of: [.text], delegate: LayerDropDelegate(
            layerIndex: layerIndex,
            draggingLayerIndex: $draggingLayerIndex,
            viewModel: viewModel.layerViewModel,
            commandManager: commandManager
        ))
        .contextMenu {
            Button("Rename") {
                editingLayerIndex = layerIndex
                editingLayerName = layer.name
            }
            Button("Duplicate") {
                viewModel.layerViewModel.duplicateLayer(at: layerIndex)
            }
            Divider()
            Button("Delete", role: .destructive) {
                if viewModel.layerViewModel.layers.count > 1 {
                    let command = DeleteLayerCommand(layerViewModel: viewModel.layerViewModel, index: layerIndex)
                    commandManager.performCommand(command)
                }
            }
            .disabled(viewModel.layerViewModel.layers.count <= 1)
        }
    }
}
