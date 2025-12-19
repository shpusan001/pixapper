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
    let layerIndex: Int
    let layerColumnWidth: CGFloat
    let cellSize: CGFloat

    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var layerViewModel: LayerViewModel
    @ObservedObject var commandManager: CommandManager

    @Binding var editingLayerIndex: Int?
    @Binding var editingLayerName: String
    @Binding var editingOpacityLayerIndex: Int?
    @Binding var opacityBeforeDrag: Double?
    @Binding var currentOpacity: Double
    @Binding var draggingLayerIndex: Int?

    // 레이어를 computed property로 변경하여 항상 최신 상태 반영
    private var layer: Layer? {
        guard layerIndex >= 0 && layerIndex < layerViewModel.layers.count else {
            return nil
        }
        return layerViewModel.layers[layerIndex]
    }

    var body: some View {
        Group {
            if let layer = layer {
                layerContent(layer: layer)
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func layerContent(layer: Layer) -> some View {
        HStack(alignment: .center, spacing: 4) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: 14)
                .fixedSize()

            // Visibility toggle - 더 명확한 UI
            Button(action: {
                layerViewModel.toggleVisibility(at: layerIndex)
            }) {
                ZStack {
                    // Invisible background for larger click area
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.001))
                        .frame(width: 28, height: 28)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(layer.isVisible ? Color.clear : Constants.Theme.textDisabled.opacity(0.2))
                        .frame(width: 22, height: 22)

                    Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(layer.isVisible ? Color.gray : Constants.Theme.textDisabled)
                }
            }
            .buttonStyle(.plain)
            .frame(width: 28, height: 28)
            .contentShape(Rectangle())
            .fixedSize()
            .help(layer.isVisible ? "Hide layer" : "Show layer")

            // Layer name and opacity
            VStack(alignment: .leading, spacing: 1) {
                // Layer name (editable)
                if editingLayerIndex == layerIndex {
                    TextField("Name", text: $editingLayerName, onCommit: {
                        if !editingLayerName.isEmpty {
                            let oldName = layer.name
                            let command = RenameLayerCommand(layerViewModel: layerViewModel, index: layerIndex, oldName: oldName, newName: editingLayerName)
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
                        .padding(.vertical, 4)
                        .padding(.horizontal, 2)
                        .background(Color.white.opacity(0.001))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            editingLayerIndex = layerIndex
                            editingLayerName = layer.name
                        }
                        .onTapGesture(count: 1) {
                            if editingLayerIndex == nil && editingOpacityLayerIndex == nil {
                                layerViewModel.selectedLayerIndex = layerIndex
                            }
                        }
                }

                // Opacity control - always visible with better UI
                HStack(spacing: 3) {
                    // Opacity label
                    Text("Opa")
                        .font(.system(size: 8))
                        .foregroundColor(Constants.Theme.textSecondary)
                        .frame(width: 22, alignment: .leading)
                        .fixedSize()

                    // Slider
                    Slider(
                        value: Binding(
                            get: { editingOpacityLayerIndex == layerIndex ? currentOpacity : layer.opacity },
                            set: { newValue in
                                if editingOpacityLayerIndex != layerIndex {
                                    editingOpacityLayerIndex = layerIndex
                                    opacityBeforeDrag = layer.opacity
                                }
                                currentOpacity = newValue
                                layerViewModel.setOpacity(at: layerIndex, opacity: newValue)
                            }
                        ),
                        in: 0...1,
                        onEditingChanged: { isEditing in
                            if !isEditing {
                                if let oldOpacity = opacityBeforeDrag {
                                    let newOpacity = currentOpacity
                                    if abs(oldOpacity - newOpacity) > 0.001 {
                                        let command = SetLayerOpacityCommand(
                                            layerViewModel: layerViewModel,
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

                    // Percentage display
                    Text("\(Int((editingOpacityLayerIndex == layerIndex ? currentOpacity : layer.opacity) * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Constants.Theme.textPrimary)
                        .frame(width: 32, alignment: .trailing)
                        .fixedSize()
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(width: layerColumnWidth, height: cellSize)
        .background(
            Group {
                if layerIndex == layerViewModel.selectedLayerIndex {
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
            viewModel: layerViewModel,
            commandManager: commandManager
        ))
        .contextMenu {
            Button("Rename") {
                editingLayerIndex = layerIndex
                editingLayerName = layer.name
            }
            Button("Duplicate") {
                layerViewModel.duplicateLayer(at: layerIndex)
            }
            Divider()
            Button("Delete", role: .destructive) {
                if layerViewModel.layers.count > 1 {
                    let command = DeleteLayerCommand(layerViewModel: layerViewModel, index: layerIndex)
                    commandManager.performCommand(command)
                }
            }
            .disabled(layerViewModel.layers.count <= 1)
        }
    }
}

