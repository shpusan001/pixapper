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
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Tools")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // Tools grid
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
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

                        ToolButton(
                            icon: "selection.pin.in.out",
                            isSelected: toolSettingsManager.selectedTool == .selection,
                            action: { toolSettingsManager.selectTool(.selection) }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                .frame(width: Constants.Layout.Tool.buttonSize, height: Constants.Layout.Tool.buttonSize)
                .background(isSelected ? Color.accentColor : Color(nsColor: .controlColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}
