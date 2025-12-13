//
//  PropertiesPanel.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

struct PropertiesPanel: View {
    @ObservedObject var toolSettingsManager: ToolSettingsManager
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                toolPropertiesView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))
    }

    @ViewBuilder
    private var toolPropertiesView: some View {
        switch toolSettingsManager.selectedTool {
        case .pencil:
            PencilPropertiesView(settings: $toolSettingsManager.pencilSettings)
        case .eraser:
            EraserPropertiesView(settings: $toolSettingsManager.eraserSettings)
        case .fill:
            FillPropertiesView(settings: $toolSettingsManager.fillSettings)
        case .rectangle:
            ShapePropertiesView(
                settings: $toolSettingsManager.rectangleSettings,
                toolName: "Rectangle"
            )
        case .circle:
            ShapePropertiesView(
                settings: $toolSettingsManager.circleSettings,
                toolName: "Circle"
            )
        case .line:
            ShapePropertiesView(
                settings: $toolSettingsManager.lineSettings,
                toolName: "Line"
            )
        case .selection:
            SelectionPropertiesView(viewModel: viewModel)
        }
    }
}

// MARK: - Pencil Properties
struct PencilPropertiesView: View {
    @Binding var settings: PencilSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Pencil")

            // Brush Size
            PropertyRow(label: "Size") {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(settings.brushSize) },
                        set: { settings.brushSize = Int($0) }
                    ), in: 1...10, step: 1)

                    Text("\(settings.brushSize)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                }
            }

            PropertyDivider()

            // Color
            PropertyRow(label: "Color") {
                ColorPicker("", selection: $settings.color, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 44, height: 32)
            }
        }
    }
}

// MARK: - Eraser Properties
struct EraserPropertiesView: View {
    @Binding var settings: EraserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Eraser")

            // Brush Size
            PropertyRow(label: "Size") {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(settings.brushSize) },
                        set: { settings.brushSize = Int($0) }
                    ), in: 1...10, step: 1)

                    Text("\(settings.brushSize)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Fill Properties
struct FillPropertiesView: View {
    @Binding var settings: FillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Fill")

            // Color
            PropertyRow(label: "Color") {
                ColorPicker("", selection: $settings.color, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 44, height: 32)
            }

            PropertyDivider()

            // Tolerance
            PropertyRow(label: "Tolerance") {
                HStack(spacing: 8) {
                    Slider(value: $settings.tolerance, in: 0...1, step: 0.01)

                    Text(String(format: "%.0f%%", settings.tolerance * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
            }
        }
    }
}

// MARK: - Shape Properties
struct ShapePropertiesView: View {
    @Binding var settings: ShapeSettings
    let toolName: String
    @State private var hasFill: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: toolName)

            // Stroke Color
            PropertyRow(label: "Stroke") {
                ColorPicker("", selection: $settings.strokeColor, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 44, height: 32)
            }

            PropertyDivider()

            // Stroke Width
            PropertyRow(label: "Width") {
                HStack(spacing: 8) {
                    Slider(value: Binding(
                        get: { Double(settings.strokeWidth) },
                        set: { settings.strokeWidth = Int($0) }
                    ), in: 1...10, step: 1)

                    Text("\(settings.strokeWidth)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 20, alignment: .trailing)
                }
            }

            PropertyDivider()

            // Fill Toggle
            PropertyRow(label: "Fill") {
                Toggle("", isOn: $hasFill)
                    .labelsHidden()
                    .onChange(of: hasFill) { _, newValue in
                        if newValue {
                            settings.fillColor = settings.strokeColor
                        } else {
                            settings.fillColor = nil
                        }
                    }
            }

            // Fill Color Picker (only when enabled)
            if hasFill {
                PropertyDivider()

                PropertyRow(label: "Fill Color") {
                    ColorPicker("", selection: Binding(
                        get: { settings.fillColor ?? .clear },
                        set: { settings.fillColor = $0 }
                    ), supportsOpacity: true)
                        .labelsHidden()
                        .frame(width: 44, height: 32)
                }
            }
        }
        .onAppear {
            hasFill = settings.fillColor != nil
        }
    }
}

// MARK: - Selection Properties
struct SelectionPropertiesView: View {
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Selection")

            if let rect = viewModel.selectionRect, viewModel.selectionPixels != nil {
                // 선택 정보
                PropertyRow(label: "Size") {
                    Text("\(Int(rect.width)) × \(Int(rect.height))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }

                PropertyDivider()

                PropertyRow(label: "Position") {
                    Text("(\(Int(rect.minX)), \(Int(rect.minY)))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                }

                PropertyDivider()

                // Transform
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transform")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                        .padding(.bottom, 6)

                    // Rotate
                    HStack(spacing: 6) {
                        TransformButton(icon: "rotate.left", tooltip: "Rotate CCW", action: viewModel.rotateSelectionCCW)
                        TransformButton(icon: "rotate.right", tooltip: "Rotate CW", action: viewModel.rotateSelectionCW)
                        TransformButton(icon: "arrow.triangle.2.circlepath", tooltip: "Rotate 180°", action: viewModel.rotateSelection180)
                    }

                    // Flip
                    HStack(spacing: 6) {
                        TransformButton(icon: "arrow.left.and.right", tooltip: "Flip Horizontal", action: viewModel.flipSelectionHorizontal)
                        TransformButton(icon: "arrow.up.and.down", tooltip: "Flip Vertical", action: viewModel.flipSelectionVertical)
                        Spacer()
                    }
                }

                PropertyDivider()

                // Actions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Actions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 6)

                    VStack(spacing: 8) {
                        // 확정 버튼
                        Button(action: {
                            viewModel.commitSelection()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12))
                                Text("Commit")
                                    .font(.system(size: 11))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                        .foregroundColor(.accentColor)
                        .help("Commit Selection (⏎)")
                        .disabled(!viewModel.isFloatingSelection)

                        // 지우기 버튼
                        Button(action: {
                            viewModel.deleteSelection()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                                Text("Delete")
                                    .font(.system(size: 11))
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 32)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red.opacity(0.15))
                        )
                        .foregroundColor(.red)
                        .help("Delete Selection (⌫)")
                    }
                }
            } else {
                Text("Select area to see properties")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Helper Views

struct PropertySectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.callout)
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .padding(.bottom, 12)
    }
}

struct PropertyDivider: View {
    var body: some View {
        Divider()
            .padding(.vertical, 8)
    }
}

struct PropertyRow<Content: View>: View {
    let label: String
    let content: Content

    init(label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            content
        }
        .padding(.vertical, 4)
    }
}

struct TransformButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .controlColor))
        )
        .foregroundColor(.primary)
        .help(tooltip)
    }
}
