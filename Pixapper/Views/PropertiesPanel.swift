//
//  PropertiesPanel.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

struct PropertiesPanel: View {
    @ObservedObject var toolSettingsManager: ToolSettingsManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Text("Properties")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

            Divider()

            // 도구별 속성 UI
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    toolPropertiesView
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
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
        case .eyedropper:
            EyedropperPropertiesView()
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
            SelectionPropertiesView()
        }
    }
}

// MARK: - Pencil Properties
struct PencilPropertiesView: View {
    @Binding var settings: PencilSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Pencil")

            Divider()
                .padding(.vertical, 12)

            // Brush Size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brush Size")
                        .font(.callout)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(settings.brushSize)px")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(settings.brushSize) },
                    set: { settings.brushSize = Int($0) }
                ), in: 1...10, step: 1)
            }
            .padding(.bottom, 16)

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.callout)
                    .foregroundColor(.primary)

                ColorPicker("", selection: $settings.color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(height: 32)
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

            Divider()
                .padding(.vertical, 12)

            // Brush Size
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Brush Size")
                        .font(.callout)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(settings.brushSize)px")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(settings.brushSize) },
                    set: { settings.brushSize = Int($0) }
                ), in: 1...10, step: 1)
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

            Divider()
                .padding(.vertical, 12)

            // Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(.callout)
                    .foregroundColor(.primary)

                ColorPicker("", selection: $settings.color, supportsOpacity: false)
                    .labelsHidden()
                    .frame(height: 32)
            }
            .padding(.bottom, 16)

            // Tolerance
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Tolerance")
                        .font(.callout)
                        .foregroundColor(.primary)
                    Spacer()
                    Text(String(format: "%.0f%%", settings.tolerance * 100))
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Slider(value: $settings.tolerance, in: 0...1, step: 0.01)

                Text("How similar colors must be to fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
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

            Divider()
                .padding(.vertical, 12)

            // Stroke Color
            VStack(alignment: .leading, spacing: 8) {
                Text("Stroke Color")
                    .font(.callout)
                    .foregroundColor(.primary)

                ColorPicker("", selection: $settings.strokeColor, supportsOpacity: false)
                    .labelsHidden()
                    .frame(height: 32)
            }
            .padding(.bottom, 16)

            // Stroke Width
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Stroke Width")
                        .font(.callout)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("\(settings.strokeWidth)px")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }

                Slider(value: Binding(
                    get: { Double(settings.strokeWidth) },
                    set: { settings.strokeWidth = Int($0) }
                ), in: 1...10, step: 1)
            }
            .padding(.bottom, 16)

            // Fill Color Toggle
            Toggle("Fill Shape", isOn: $hasFill)
                .font(.callout)
                .onChange(of: hasFill) { newValue in
                    if newValue {
                        settings.fillColor = settings.strokeColor
                    } else {
                        settings.fillColor = nil
                    }
                }
                .padding(.bottom, hasFill ? 16 : 0)

            // Fill Color Picker (only when enabled)
            if hasFill {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fill Color")
                        .font(.callout)
                        .foregroundColor(.primary)

                    ColorPicker("", selection: Binding(
                        get: { settings.fillColor ?? .clear },
                        set: { settings.fillColor = $0 }
                    ), supportsOpacity: false)
                        .labelsHidden()
                        .frame(height: 32)
                }
            }
        }
        .onAppear {
            hasFill = settings.fillColor != nil
        }
    }
}

// MARK: - Eyedropper Properties
struct EyedropperPropertiesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Eyedropper")

            Divider()
                .padding(.vertical, 12)

            Text("Click on the canvas to pick a color from any pixel.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Selection Properties
struct SelectionPropertiesView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Selection")

            Divider()
                .padding(.vertical, 12)

            Text("Drag to select a rectangular area. Selection tool features coming soon.")
                .font(.callout)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Helper Views
struct PropertySectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.primary)
    }
}
