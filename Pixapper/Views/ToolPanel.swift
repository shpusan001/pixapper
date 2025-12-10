//
//  ToolPanel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ToolPanel: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolSettingsManager: ToolSettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Tools section
            VStack(alignment: .leading, spacing: 8) {
                Text("Tools")
                    .font(.headline)

                // Row 1
                HStack(spacing: 8) {
                    ToolButton(
                        icon: "pencil",
                        isSelected: toolSettingsManager.selectedTool == .pencil,
                        action: { toolSettingsManager.selectTool(.pencil) }
                    )

                    ToolButton(
                        icon: "eraser",
                        isSelected: toolSettingsManager.selectedTool == .eraser,
                        action: { toolSettingsManager.selectTool(.eraser) }
                    )

                    ToolButton(
                        icon: "paintbrush.fill",
                        isSelected: toolSettingsManager.selectedTool == .fill,
                        action: { toolSettingsManager.selectTool(.fill) }
                    )

                    ToolButton(
                        icon: "eyedropper",
                        isSelected: toolSettingsManager.selectedTool == .eyedropper,
                        action: { toolSettingsManager.selectTool(.eyedropper) }
                    )
                }

                // Row 2
                HStack(spacing: 8) {
                    ToolButton(
                        icon: "rectangle",
                        isSelected: toolSettingsManager.selectedTool == .rectangle,
                        action: { toolSettingsManager.selectTool(.rectangle) }
                    )

                    ToolButton(
                        icon: "circle",
                        isSelected: toolSettingsManager.selectedTool == .circle,
                        action: { toolSettingsManager.selectTool(.circle) }
                    )

                    ToolButton(
                        icon: "line.diagonal",
                        isSelected: toolSettingsManager.selectedTool == .line,
                        action: { toolSettingsManager.selectTool(.line) }
                    )

                    Spacer()
                        .frame(width: 44)
                }
            }

            Divider()

            // Color picker section
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.headline)

                HStack(spacing: 12) {
                    // Current color
                    VStack(spacing: 4) {
                        ColorWell(color: $toolSettingsManager.currentColor)
                            .frame(width: 50, height: 50)
                        Text(toolSettingsManager.selectedTool.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Divider()

            // Zoom controls
            VStack(alignment: .leading, spacing: 8) {
                Text("Zoom")
                    .font(.headline)

                HStack {
                    Slider(value: $viewModel.zoomLevel, in: 100...1600, step: 100)
                    Text("\(Int(viewModel.zoomLevel))%")
                        .font(.callout)
                        .frame(width: 60, alignment: .trailing)
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(width: 240)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct ToolButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.accentColor : Color(nsColor: .controlColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct ColorWell: View {
    @Binding var color: Color

    var body: some View {
        ColorPicker("", selection: $color)
            .labelsHidden()
            .frame(width: 50, height: 50)
    }
}
