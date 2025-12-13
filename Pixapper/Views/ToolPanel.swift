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
        ScrollView {
            VStack(alignment: .center, spacing: 0) {
                // Draw tools
                VStack(spacing: 2) {
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
                }

                Divider()
                    .padding(.vertical, 8)

                // Shape tools
                VStack(spacing: 2) {
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

                Divider()
                    .padding(.vertical, 8)

                // Selection tool
                VStack(spacing: 2) {
                    ToolIconButton(
                        icon: "selection.pin.in.out",
                        tooltip: "Selection (V)",
                        isSelected: toolSettingsManager.selectedTool == .selection,
                        action: { toolSettingsManager.selectTool(.selection) }
                    )
                }
            }
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
    }
}

// Adobe-style icon-only tool button
struct ToolIconButton: View {
    let icon: String
    let tooltip: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .regular))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .foregroundColor(isSelected ? Color.accentColor : .primary)
        .help(tooltip)
    }
}

// MARK: - Canvas Size Sheet

struct CanvasSizeSheet: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Environment(\.dismiss) var dismiss
    @State private var width: String = ""
    @State private var height: String = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("Resize Canvas")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                // Width
                HStack {
                    Text("Width:")
                        .frame(width: 60, alignment: .leading)
                    TextField("Width", text: $width)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("px")
                        .foregroundColor(.secondary)
                }

                // Height
                HStack {
                    Text("Height:")
                        .frame(width: 60, alignment: .leading)
                    TextField("Height", text: $height)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    Text("px")
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Resize") {
                    if let w = Int(width), let h = Int(height),
                       w > 0, w <= 1024, h > 0, h <= 1024 {
                        viewModel.resizeCanvas(width: w, height: h)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(24)
        .frame(width: Constants.Layout.Panel.toolPanelWidth)
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
