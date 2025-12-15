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
        VStack(spacing: 0) {
            // Scrollable tools section
            ScrollView {
                VStack(spacing: 0) {
                    // Draw tools
                    VStack(spacing: 0) {
                        ToolIconButton(
                            icon: "pencil",
                            tooltip: "Pencil (B)",
                            isSelected: toolSettingsManager.selectedTool == .pencil,
                            action: { toolSettingsManager.selectTool(.pencil) }
                        )

                        ToolIconButton(
                            icon: "eraser",
                            tooltip: "Eraser (E)",
                            isSelected: toolSettingsManager.selectedTool == .eraser,
                            action: { toolSettingsManager.selectTool(.eraser) }
                        )

                        ToolIconButton(
                            icon: "paintbrush.fill",
                            tooltip: "Fill (G)",
                            isSelected: toolSettingsManager.selectedTool == .fill,
                            action: { toolSettingsManager.selectTool(.fill) }
                        )

                        ToolIconButton(
                            icon: "square.lefthalf.filled",
                            tooltip: "Mirror (M)",
                            isSelected: toolSettingsManager.selectedTool == .mirror,
                            action: { toolSettingsManager.selectTool(.mirror) }
                        )

                        ToolIconButton(
                            icon: "circle.grid.cross",
                            tooltip: "Dithering (D)",
                            isSelected: toolSettingsManager.selectedTool == .dithering,
                            action: { toolSettingsManager.selectTool(.dithering) }
                        )
                    }

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // Shape tools
                    VStack(spacing: 0) {
                        ToolIconButton(
                            icon: "rectangle",
                            tooltip: "Rectangle (U)",
                            isSelected: toolSettingsManager.selectedTool == .rectangle,
                            action: { toolSettingsManager.selectTool(.rectangle) }
                        )

                        ToolIconButton(
                            icon: "circle",
                            tooltip: "Circle (O)",
                            isSelected: toolSettingsManager.selectedTool == .circle,
                            action: { toolSettingsManager.selectTool(.circle) }
                        )

                        ToolIconButton(
                            icon: "line.diagonal",
                            tooltip: "Line (L)",
                            isSelected: toolSettingsManager.selectedTool == .line,
                            action: { toolSettingsManager.selectTool(.line) }
                        )
                    }

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // Selection tool
                    VStack(spacing: 0) {
                        ToolIconButton(
                            icon: "selection.pin.in.out",
                            tooltip: "Selection (V)",
                            isSelected: toolSettingsManager.selectedTool == .selection,
                            action: { toolSettingsManager.selectTool(.selection) }
                        )
                    }
                }
                .frame(width: 50)
            }

            // Color swatch (항상 하단에 고정)
            CompactColorSwatchView(colorManager: toolSettingsManager.colorManager)
                .padding(.bottom, 10)
        }
        .frame(width: 50)
        .background(Constants.Theme.panelBackground)
    }
}

// Adobe-style icon-only tool button
struct ToolIconButton: View {
    let icon: String
    let tooltip: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .frame(width: 50, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isSelected ? Constants.Theme.sectionBackground : (isHovered ? Constants.Theme.hoverBackground : Color.clear))
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? Constants.Theme.accentBlue : Color.clear)
                .frame(width: 2)
            , alignment: .leading
        )
        .foregroundColor(isSelected ? Constants.Theme.accentBlue : Constants.Theme.textSecondary)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Canvas Size Sheet

struct CanvasSizeSheet: View {
    @ObservedObject var viewModel: CanvasViewModel
    var commandManager: CommandManager?
    @Environment(\.dismiss) var dismiss
    @State private var width: String = ""
    @State private var height: String = ""

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Resize Canvas")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Constants.Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 10) {
                // Width
                HStack(spacing: 8) {
                    Text("Width:")
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Theme.textSecondary)
                        .frame(width: 55, alignment: .leading)
                    TextField("Width", text: $width)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(2)
                        .frame(width: 80)
                    Text("px")
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Theme.textSecondary)
                }

                // Height
                HStack(spacing: 8) {
                    Text("Height:")
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Theme.textSecondary)
                        .frame(width: 55, alignment: .leading)
                    TextField("Height", text: $height)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(2)
                        .frame(width: 80)
                    Text("px")
                        .font(.system(size: 11))
                        .foregroundColor(Constants.Theme.textSecondary)
                }
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)
                .padding(.vertical, 4)

            // Buttons
            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Constants.Theme.sectionBackground)
                .foregroundColor(Constants.Theme.textPrimary)
                .cornerRadius(2)
                .keyboardShortcut(.cancelAction)

                Button("Resize") {
                    if let w = Int(width), let h = Int(height),
                       w > 0, w <= 1024, h > 0, h <= 1024 {
                        let oldWidth = viewModel.canvas.width
                        let oldHeight = viewModel.canvas.height

                        // CommandManager가 있으면 Command로 실행
                        if let commandManager = commandManager {
                            let command = ResizeCanvasCommand(
                                canvasViewModel: viewModel,
                                oldWidth: oldWidth,
                                oldHeight: oldHeight,
                                newWidth: w,
                                newHeight: h
                            )
                            commandManager.performCommand(command)
                        } else {
                            // CommandManager가 없으면 직접 실행 (fallback)
                            viewModel.resizeCanvas(width: w, height: h)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isValid ? Constants.Theme.accentBlue : Constants.Theme.sectionBackground)
                .foregroundColor(isValid ? .white : Constants.Theme.textDisabled)
                .cornerRadius(2)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 280)
        .background(Constants.Theme.panelBackground)
        .onAppear {
            width = "\(viewModel.canvas.width)"
            height = "\(viewModel.canvas.height)"
        }
    }

    private var isValid: Bool {
        guard let w = Int(width), let h = Int(height) else { return false }
        return w > 0 && w <= 1024 && h > 0 && h <= 1024
    }
}
