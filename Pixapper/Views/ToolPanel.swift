//
//  ToolPanel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ToolPanel: View {
    @ObservedObject var viewModel: CanvasViewModel

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
                        isSelected: viewModel.selectedTool == .pencil,
                        action: { viewModel.selectedTool = .pencil }
                    )

                    ToolButton(
                        icon: "eraser",
                        isSelected: viewModel.selectedTool == .eraser,
                        action: { viewModel.selectedTool = .eraser }
                    )

                    ToolButton(
                        icon: "paintbrush.fill",
                        isSelected: viewModel.selectedTool == .fill,
                        action: { viewModel.selectedTool = .fill }
                    )

                    ToolButton(
                        icon: "eyedropper",
                        isSelected: viewModel.selectedTool == .eyedropper,
                        action: { viewModel.selectedTool = .eyedropper }
                    )
                }

                // Row 2
                HStack(spacing: 8) {
                    ToolButton(
                        icon: "rectangle",
                        isSelected: viewModel.selectedTool == .rectangle,
                        action: { viewModel.selectedTool = .rectangle }
                    )

                    ToolButton(
                        icon: "circle",
                        isSelected: viewModel.selectedTool == .circle,
                        action: { viewModel.selectedTool = .circle }
                    )

                    ToolButton(
                        icon: "line.diagonal",
                        isSelected: viewModel.selectedTool == .line,
                        action: { viewModel.selectedTool = .line }
                    )

                    Spacer()
                        .frame(width: 44)
                }
            }

            Divider()

            // Color picker section
            VStack(alignment: .leading, spacing: 8) {
                Text("Colors")
                    .font(.headline)

                HStack(spacing: 12) {
                    // Primary color
                    VStack(spacing: 4) {
                        ColorWell(color: $viewModel.primaryColor)
                            .frame(width: 50, height: 50)
                        Text("Primary")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Swap button
                    Button(action: viewModel.swapColors) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.body)
                    }
                    .buttonStyle(.plain)
                    .help("Swap colors")

                    // Secondary color
                    VStack(spacing: 4) {
                        ColorWell(color: $viewModel.secondaryColor)
                            .frame(width: 50, height: 50)
                        Text("Secondary")
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
