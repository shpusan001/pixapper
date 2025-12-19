//
//  ToolPanel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

/// Adobe 스타일 툴 패널 - 조밀하고 전문적
struct ToolPanel: View {
    @ObservedObject var viewModel: CanvasViewModel
    @ObservedObject var toolSettingsManager: ToolSettingsManager

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 2) {
                    // Draw tools
                    VStack(spacing: 2) {
                        AdobeToolButton(
                            icon: "pencil",
                            tooltip: "Pencil (B)",
                            isSelected: toolSettingsManager.selectedTool == .pencil,
                            action: { toolSettingsManager.selectTool(.pencil) }
                        )

                        AdobeToolButton(
                            icon: "eraser",
                            tooltip: "Eraser (E)",
                            isSelected: toolSettingsManager.selectedTool == .eraser,
                            action: { toolSettingsManager.selectTool(.eraser) }
                        )

                        AdobeToolButton(
                            icon: "paintbrush.fill",
                            tooltip: "Fill (G)",
                            isSelected: toolSettingsManager.selectedTool == .fill,
                            action: { toolSettingsManager.selectTool(.fill) }
                        )

                        AdobeToolButton(
                            icon: "square.lefthalf.filled",
                            tooltip: "Mirror (M)",
                            isSelected: toolSettingsManager.selectedTool == .mirror,
                            action: { toolSettingsManager.selectTool(.mirror) }
                        )

                        AdobeToolButton(
                            icon: "circle.grid.cross",
                            tooltip: "Dithering (D)",
                            isSelected: toolSettingsManager.selectedTool == .dithering,
                            action: { toolSettingsManager.selectTool(.dithering) }
                        )

                        AdobeToolButton(
                            icon: "textformat",
                            tooltip: "Text (T)",
                            isSelected: toolSettingsManager.selectedTool == .text,
                            action: { toolSettingsManager.selectTool(.text) }
                        )
                    }

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)
                        .padding(.vertical, 4)

                    // Shape tools
                    VStack(spacing: 2) {
                        AdobeToolButton(
                            icon: "rectangle",
                            tooltip: "Rectangle (U)",
                            isSelected: toolSettingsManager.selectedTool == .rectangle,
                            action: { toolSettingsManager.selectTool(.rectangle) }
                        )

                        AdobeToolButton(
                            icon: "circle",
                            tooltip: "Circle (O)",
                            isSelected: toolSettingsManager.selectedTool == .circle,
                            action: { toolSettingsManager.selectTool(.circle) }
                        )

                        AdobeToolButton(
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
                    VStack(spacing: 2) {
                        AdobeToolButton(
                            icon: toolSettingsManager.selectionSettings.selectionType.icon,
                            tooltip: "Selection (V) - \(toolSettingsManager.selectionSettings.selectionType.displayName)",
                            isSelected: toolSettingsManager.selectedTool == .selection,
                            action: { toolSettingsManager.selectTool(.selection) }
                        )
                    }
                }
                .padding(.vertical, 6)
            }
        }
        .frame(width: 48)
        .background(Constants.Theme.panelBackground)
    }
}

// MARK: - Adobe Style Tool Button
struct AdobeToolButton: View {
    let icon: String
    let tooltip: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Background
                if isSelected {
                    Rectangle()
                        .fill(Constants.Theme.sectionBackground)
                } else if isHovered {
                    Rectangle()
                        .fill(Constants.Theme.hoverBackground)
                }

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(isSelected ? Constants.Theme.textPrimary : Constants.Theme.textSecondary)
            }
            .frame(width: 48, height: 36)
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Canvas Size Sheet (Adobe Style)

struct CanvasSizeSheet: View {
    @ObservedObject var viewModel: CanvasViewModel
    var commandManager: CommandManager?
    @Environment(\.dismiss) var dismiss
    @State private var width: String = ""
    @State private var height: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("RESIZE CANVAS")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Constants.Theme.textPrimary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Constants.Theme.sectionBackground)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                // Width
                HStack(spacing: 8) {
                    Text("Width:")
                        .font(.system(size: 10))
                        .foregroundColor(Constants.Theme.textSecondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("Width", text: $width)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(2)
                        .frame(width: 70)
                    Text("px")
                        .font(.system(size: 10))
                        .foregroundColor(Constants.Theme.textSecondary)
                }

                // Height
                HStack(spacing: 8) {
                    Text("Height:")
                        .font(.system(size: 10))
                        .foregroundColor(Constants.Theme.textSecondary)
                        .frame(width: 50, alignment: .leading)
                    TextField("Height", text: $height)
                        .textFieldStyle(.plain)
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(2)
                        .frame(width: 70)
                    Text("px")
                        .font(.system(size: 10))
                        .foregroundColor(Constants.Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Buttons
            HStack(spacing: 6) {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
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
                            viewModel.resizeCanvas(width: w, height: h)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isValid ? Constants.Theme.accentBlue : Constants.Theme.sectionBackground)
                .foregroundColor(isValid ? .white : Constants.Theme.textDisabled)
                .cornerRadius(2)
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .frame(width: 240)
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
