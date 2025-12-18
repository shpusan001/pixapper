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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PROPERTIES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Constants.Theme.textSecondary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Constants.Theme.sectionBackground)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Tool properties content
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    toolPropertiesView
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Constants.Theme.panelBackground)
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
            SelectionPropertiesView(
                viewModel: viewModel,
                settings: Binding(
                    get: { toolSettingsManager.selectionSettings },
                    set: { toolSettingsManager.selectionSettings = $0 }
                )
            )
        case .mirror:
            MirrorPropertiesView(settings: $toolSettingsManager.mirrorSettings)
        case .dithering:
            DitheringPropertiesView(
                settings: $toolSettingsManager.ditheringSettings,
                colorManager: toolSettingsManager.colorManager
            )
        case .text:
            TextPropertiesView(settings: $toolSettingsManager.textSettings)
        }
    }
}

// MARK: - Mirror Properties
struct MirrorPropertiesView: View {
    @Binding var settings: MirrorSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Mirror")

            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Size") {
                    LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                }

                PropertyDivider()

                PropertyRow(label: "Mode") {
                    Picker("", selection: $settings.mode) {
                        ForEach(MirrorMode.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.system(size: 9))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Dithering Properties
struct DitheringPropertiesView: View {
    @Binding var settings: DitheringSettings
    @ObservedObject var colorManager: ColorManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Dithering")

            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Size") {
                    LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                }

                PropertyDivider()

                PropertyRow(label: "Pattern") {
                    Picker("", selection: $settings.pattern) {
                        ForEach(DitheringPattern.allCases) { pattern in
                            Text(pattern.displayName).tag(pattern)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.system(size: 9))
                }

                // Custom Pattern Editor
                if settings.pattern == .custom {
                    PropertyDivider()

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Grid Size")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Constants.Theme.textSecondary)

                            Spacer()

                            Picker("", selection: Binding(
                                get: { settings.customPatternSize },
                                set: { newSize in
                                    settings.resizeCustomPattern(newSize: newSize)
                                }
                            )) {
                                Text("2×2").tag(2)
                                Text("4×4").tag(4)
                                Text("8×8").tag(8)
                                Text("16×16").tag(16)
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .font(.system(size: 9))
                            .frame(width: 70)
                        }

                        CustomPatternEditor(
                            pattern: $settings.customPattern,
                            size: settings.customPatternSize,
                            color1: colorManager.primaryColor,
                            color2: colorManager.secondaryColor
                        )
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Custom Pattern Editor
struct CustomPatternEditor: View {
    @Binding var pattern: [[Bool]]
    let size: Int
    let color1: Color
    let color2: Color

    private var cellSize: CGFloat {
        // 전체 크기를 160으로 유지하되, 그리드 크기에 따라 셀 크기 조정
        let totalSize: CGFloat = 160
        let spacing: CGFloat = 2
        let totalSpacing = CGFloat(size - 1) * spacing
        return (totalSize - totalSpacing) / CGFloat(size)
    }

    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<size, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<size, id: \.self) { col in
                        Button(action: {
                            if row < pattern.count && col < pattern[row].count {
                                pattern[row][col].toggle()
                            }
                        }) {
                            Rectangle()
                                .fill(
                                    (row < pattern.count && col < pattern[row].count && pattern[row][col])
                                    ? color1 : color2
                                )
                                .frame(width: cellSize, height: cellSize)
                        }
                        .buttonStyle(.plain)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                        )
                    }
                }
            }
        }
        .frame(height: 160)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
    }
}

// MARK: - Pencil Properties
struct PencilPropertiesView: View {
    @Binding var settings: PencilSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Pencil")

            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Size") {
                    LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Eraser Properties
struct EraserPropertiesView: View {
    @Binding var settings: EraserSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Eraser")

            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Size") {
                    LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Fill Properties
struct FillPropertiesView: View {
    @Binding var settings: FillSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Fill")

            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Tolerance") {
                    HStack(spacing: 6) {
                        Slider(value: $settings.tolerance, in: 0...1, step: 0.01)
                            .tint(Constants.Theme.accentBlue)

                        Text(String(format: "%.0f%%", settings.tolerance * 100))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                            .frame(width: 32, alignment: .trailing)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(Constants.Theme.sectionBackground)
                            .cornerRadius(2)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Shape Properties
struct ShapePropertiesView: View {
    @Binding var settings: ShapeSettings
    let toolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: toolName)

            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Width") {
                    LabeledSlider(value: $settings.strokeWidth, range: 1...10, step: 1)
                }

                PropertyDivider()

                PropertyRow(label: "Fill") {
                    Toggle("", isOn: $settings.isFilled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Selection Properties
struct SelectionPropertiesView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var settings: SelectionSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Selection")

            // Selection Mode
            VStack(alignment: .leading, spacing: 6) {
                PropertyRow(label: "Mode") {
                    Picker("", selection: $settings.selectionType) {
                        ForEach(SelectionType.allCases) { type in
                            HStack {
                                Image(systemName: type.icon)
                                    .font(.system(size: 8))
                                Text(type.displayName)
                            }
                            .tag(type)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .font(.system(size: 9))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)

            PropertyDivider()

            if let rect = viewModel.selectionRect, viewModel.selectionPixels != nil {
                VStack(alignment: .leading, spacing: 6) {
                    PropertyRow(label: "Size") {
                        Text("\(Int(rect.width)) × \(Int(rect.height))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                    }

                    PropertyDivider()

                    PropertyRow(label: "Position") {
                        Text("(\(Int(rect.minX)), \(Int(rect.minY)))")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                    }

                    PropertyDivider()

                    // Transform
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Transform")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Constants.Theme.textSecondary)

                        // Rotate
                        HStack(spacing: 4) {
                            TransformButton(icon: "rotate.left", tooltip: "Rotate CCW", action: viewModel.rotateSelectionCCW)
                            TransformButton(icon: "rotate.right", tooltip: "Rotate CW", action: viewModel.rotateSelectionCW)
                            TransformButton(icon: "arrow.triangle.2.circlepath", tooltip: "Rotate 180°", action: viewModel.rotateSelection180)
                        }

                        // Flip
                        HStack(spacing: 4) {
                            TransformButton(icon: "arrow.left.and.right", tooltip: "Flip Horizontal", action: viewModel.flipSelectionHorizontal)
                            TransformButton(icon: "arrow.up.and.down", tooltip: "Flip Vertical", action: viewModel.flipSelectionVertical)
                            Spacer()
                        }
                    }

                PropertyDivider()

                // Actions
                VStack(alignment: .leading, spacing: 6) {
                    Text("Actions")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Constants.Theme.textSecondary)

                    VStack(spacing: 4) {
                        // Commit button
                        Button(action: {
                            viewModel.commitSelection()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 9))
                                Text("Commit")
                                    .font(.system(size: 9, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            Rectangle()
                                .fill(Constants.Theme.accentBlue.opacity(0.15))
                        )
                        .foregroundColor(Constants.Theme.accentBlue)
                        .help("Commit Selection (⏎)")
                        .disabled(!viewModel.isFloatingSelection)

                        // Delete button
                        Button(action: {
                            viewModel.deleteSelection()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 9))
                                Text("Delete")
                                    .font(.system(size: 9, weight: .medium))
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                            .frame(height: 24)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            Rectangle()
                                .fill(Color.red.opacity(0.1))
                        )
                        .foregroundColor(.red)
                        .help("Delete Selection (⌫)")
                    }
                }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            } else {
                Text("Select area to see properties")
                    .font(.system(size: 9))
                    .foregroundColor(Constants.Theme.textDisabled)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Helper Views (Adobe Style)

struct PropertySectionHeader: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 9, weight: .semibold))
            .foregroundColor(Constants.Theme.textSecondary)
            .tracking(0.3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Constants.Theme.sectionBackground)
    }
}

struct PropertyDivider: View {
    var body: some View {
        Rectangle()
            .fill(Constants.Theme.divider)
            .frame(height: 1)
            .padding(.vertical, 4)
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
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(Constants.Theme.textSecondary)

            content
        }
        .padding(.vertical, 2)
    }
}

struct TransformButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Rectangle()
                .fill(isHovered ? Constants.Theme.hoverBackground : Constants.Theme.sectionBackground)
        )
        .foregroundColor(Constants.Theme.textPrimary)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct LabeledSlider: View {
    let value: Binding<Int>
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(value.wrappedValue) },
                    set: { value.wrappedValue = Int($0) }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .tint(Constants.Theme.accentBlue)

            Text("\(value.wrappedValue)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Constants.Theme.textPrimary)
                .frame(width: 20, alignment: .trailing)
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Constants.Theme.sectionBackground)
                .cornerRadius(2)
        }
    }
}

struct CompactColorPicker: View {
    let selection: Binding<Color>

    var body: some View {
        ColorPicker("", selection: selection)
            .labelsHidden()
            .frame(height: 24)
    }
}

// MARK: - Text Properties
struct TextPropertiesView: View {
    @Binding var settings: TextToolSettings

    // 시스템 폰트 목록
    private let availableFonts: [String] = {
        let fontFamilies = NSFontManager.shared.availableFontFamilies.sorted()
        // 자주 사용하는 폰트를 상단에 배치
        let commonFonts = ["Courier", "Helvetica", "Arial", "Monaco", "Menlo", "SF Mono"]
        let otherFonts = fontFamilies.filter { !commonFonts.contains($0) }
        return commonFonts + otherFonts
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PropertySectionHeader(title: "Text")

            VStack(alignment: .leading, spacing: 6) {
                // Font
                PropertyRow(label: "Font") {
                    Picker("", selection: $settings.fontName) {
                        ForEach(availableFonts, id: \.self) { fontName in
                            Text(fontName)
                                .font(.custom(fontName, size: 12))
                                .tag(fontName)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }

                // Size
                PropertyRow(label: "Size") {
                    LabeledSlider(
                        value: Binding(
                            get: { Int(settings.fontSize) },
                            set: { settings.fontSize = CGFloat($0) }
                        ),
                        range: 6...24,
                        step: 2
                    )
                }

                // Style toggles
                PropertyRow(label: "Style") {
                    HStack(spacing: 8) {
                        Toggle("Bold", isOn: $settings.isBold)
                            .toggleStyle(.button)
                            .controlSize(.small)

                        Toggle("Italic", isOn: $settings.isItalic)
                            .toggleStyle(.button)
                            .controlSize(.small)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }
}
