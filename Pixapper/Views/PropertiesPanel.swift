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
        HStack(spacing: 0) {
            // Tool properties content
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 12) {
                    toolPropertiesView
                }
                .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 42)
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
            FillPropertiesView(
                settings: $toolSettingsManager.fillSettings,
                colorManager: toolSettingsManager.colorManager,
                paletteManager: viewModel.timelineViewModel?.pixelStateManager.paletteManager ?? PaletteManager()
            )
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
        HStack(spacing: 8) {
            Text("MIRROR")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Size") {
                LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                    .frame(width: 100)
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 20)

            PropertyRow(label: "Mode") {
                Picker("", selection: $settings.mode) {
                    ForEach(MirrorMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.system(size: 11))
                .frame(width: 100)
            }
        }
    }
}

// MARK: - Dithering Properties
struct DitheringPropertiesView: View {
    @Binding var settings: DitheringSettings
    @ObservedObject var colorManager: ColorManager

    @State private var showCustomEditor = false

    var body: some View {
        HStack(spacing: 8) {
            Text("DITHERING")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Size") {
                LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                    .frame(width: 100)
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 20)

            PropertyRow(label: "Pattern") {
                Picker("", selection: $settings.pattern) {
                    ForEach(DitheringPattern.allCases) { pattern in
                        Text(pattern.displayName).tag(pattern)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.system(size: 11))
                .frame(width: 100)
            }

            if settings.pattern == .custom {
                Rectangle()
                    .fill(Constants.Theme.divider)
                    .frame(width: 1, height: 20)

                Button("Edit") {
                    showCustomEditor.toggle()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Constants.Theme.sectionBackground)
                .cornerRadius(3)
                .popover(isPresented: $showCustomEditor) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("Custom Pattern")
                                .font(.system(size: 11, weight: .semibold))
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
                            .font(.system(size: 11))
                        }

                        CustomPatternEditor(
                            pattern: $settings.customPattern,
                            size: settings.customPatternSize,
                            color1: colorManager.primaryColor,
                            color2: colorManager.secondaryColor
                        )
                    }
                    .padding(12)
                    .frame(width: 220)
                }
            }
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
        HStack(spacing: 8) {
            Text("PENCIL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Size") {
                LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                    .frame(width: 100)
            }
        }
    }
}

// MARK: - Eraser Properties
struct EraserPropertiesView: View {
    @Binding var settings: EraserSettings

    var body: some View {
        HStack(spacing: 8) {
            Text("ERASER")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Size") {
                LabeledSlider(value: $settings.brushSize, range: 1...10, step: 1)
                    .frame(width: 100)
            }
        }
    }
}

// MARK: - Fill Properties
struct FillPropertiesView: View {
    @Binding var settings: FillSettings
    @ObservedObject var colorManager: ColorManager
    @ObservedObject var paletteManager: PaletteManager

    var body: some View {
        HStack(spacing: 8) {
            Text("FILL")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            // Fill Type
            PropertyRow(label: "Type") {
                Picker("", selection: $settings.fillType) {
                    Text("Solid").tag(FillType.solid)
                    Text("Linear").tag(FillType.linear)
                    Text("Radial").tag(FillType.radial)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .help("Solid: Single color\nLinear: Drag to set gradient direction\nRadial: Drag to set gradient radius")
            }

            // Tolerance
            PropertyRow(label: "Tolerance") {
                HStack(spacing: 4) {
                    Slider(value: $settings.tolerance, in: 0...1, step: 0.01)
                        .tint(Constants.Theme.accentBlue)
                        .frame(width: 80)

                    Text(String(format: "%.0f%%", settings.tolerance * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Constants.Theme.textPrimary)
                        .frame(width: 32, alignment: .trailing)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(2)
                }
                .help("Color similarity threshold: 0% = exact match only, 100% = fill all colors")
            }

            // Gradient hint
            if settings.fillType != .solid {
                Text(settings.fillType == .linear ? "Drag to set gradient direction" : "Drag from center to set radius")
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Theme.textSecondary)
                    .padding(.leading, 4)
            }
        }
    }
}

// MARK: - Shape Properties
struct ShapePropertiesView: View {
    @Binding var settings: ShapeSettings
    let toolName: String

    var body: some View {
        HStack(spacing: 8) {
            Text(toolName.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Width") {
                LabeledSlider(value: $settings.strokeWidth, range: 1...10, step: 1)
                    .frame(width: 100)
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 20)

            PropertyRow(label: "Fill") {
                Toggle("", isOn: $settings.isFilled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
        }
    }
}

// MARK: - Selection Properties
struct SelectionPropertiesView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var settings: SelectionSettings

    var body: some View {
        HStack(spacing: 8) {
            Text("SELECTION")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Mode") {
                Picker("", selection: $settings.selectionType) {
                    ForEach(SelectionType.allCases) { type in
                        HStack {
                            Image(systemName: type.icon)
                                .font(.system(size: 9))
                            Text(type.displayName)
                        }
                        .tag(type)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.system(size: 11))
                .frame(width: 100)
            }

            if let rect = viewModel.selectionRect, viewModel.selectionPixels != nil {
                Rectangle()
                    .fill(Constants.Theme.divider)
                    .frame(width: 1, height: 20)

                Text("\(Int(rect.width))×\(Int(rect.height))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Constants.Theme.textSecondary)

                Rectangle()
                    .fill(Constants.Theme.divider)
                    .frame(width: 1, height: 20)

                // Transform buttons
                HStack(spacing: 4) {
                    CompactTransformButton(icon: "rotate.left", tooltip: "Rotate CCW", action: viewModel.rotateSelectionCCW)
                    CompactTransformButton(icon: "rotate.right", tooltip: "Rotate CW", action: viewModel.rotateSelectionCW)
                    CompactTransformButton(icon: "arrow.left.and.right", tooltip: "Flip H", action: viewModel.flipSelectionHorizontal)
                    CompactTransformButton(icon: "arrow.up.and.down", tooltip: "Flip V", action: viewModel.flipSelectionVertical)
                }

                Rectangle()
                    .fill(Constants.Theme.divider)
                    .frame(width: 1, height: 20)

                // Action buttons
                HStack(spacing: 4) {
                    Button(action: viewModel.commitSelection) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .background(Constants.Theme.accentBlue.opacity(0.15))
                    .foregroundColor(Constants.Theme.accentBlue)
                    .cornerRadius(3)
                    .help("Commit (⏎)")
                    .disabled(!viewModel.isFloatingSelection)

                    Button(action: viewModel.deleteSelection) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(3)
                    .help("Delete (⌫)")
                }
            } else {
                Rectangle()
                    .fill(Constants.Theme.divider)
                    .frame(width: 1, height: 20)

                Text("No active selection")
                    .font(.system(size: 11))
                    .foregroundColor(Constants.Theme.textDisabled)
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
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(minWidth: 40)

            content
        }
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

struct CompactTransformButton: View {
    let icon: String
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .frame(width: 24, height: 24)
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
        HStack(spacing: 4) {
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
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Constants.Theme.textPrimary)
                .frame(width: 24, alignment: .trailing)
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
        HStack(spacing: 8) {
            Text("TEXT")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Constants.Theme.textSecondary)
                .tracking(0.3)

            PropertyRow(label: "Font") {
                Picker("", selection: $settings.fontName) {
                    ForEach(availableFonts, id: \.self) { fontName in
                        Text(fontName)
                            .font(.custom(fontName, size: 11))
                            .tag(fontName)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .font(.system(size: 11))
                .frame(width: 100)
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 20)

            PropertyRow(label: "Size") {
                LabeledSlider(
                    value: Binding(
                        get: { Int(settings.fontSize) },
                        set: { settings.fontSize = CGFloat($0) }
                    ),
                    range: 6...24,
                    step: 2
                )
                .frame(width: 100)
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 20)

            PropertyRow(label: "Style") {
                HStack(spacing: 4) {
                    Toggle("B", isOn: $settings.isBold)
                        .toggleStyle(.button)
                        .font(.system(size: 10, weight: .bold))
                        .controlSize(.mini)
                        .frame(width: 24, height: 24)

                    Toggle("I", isOn: $settings.isItalic)
                        .toggleStyle(.button)
                        .font(.system(size: 10).italic())
                        .controlSize(.mini)
                        .frame(width: 24, height: 24)
                }
            }
        }
    }
}

// MARK: - Gradient Stop Editor (Adobe Style)
struct GradientStopEditor: View {
    @Binding var stops: [GradientStop]
    @ObservedObject var paletteManager: PaletteManager
    @State private var selectedStopIndex: Int? = nil
    @State private var draggingIndex: Int? = nil
    @State private var showingPalettePicker = false

    private let barHeight: CGFloat = 24
    private let barWidth: CGFloat = 200
    private let markerSize: CGFloat = 12

    var body: some View {
        VStack(spacing: 8) {
            // 그래디언트 바 + 마커
            ZStack(alignment: .topLeading) {
                // 그래디언트 미리보기 바
                GradientPreviewBar(stops: stops, paletteManager: paletteManager)
                    .frame(width: barWidth, height: barHeight)
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Constants.Theme.divider, lineWidth: 1)
                    )
                    .onTapGesture { location in
                        addStopAt(location: location)
                    }

                // 마커들 (바 위에 배치)
                ForEach(stops.indices, id: \.self) { index in
                    GradientStopMarker(
                        stop: $stops[index],
                        isSelected: selectedStopIndex == index,
                        color: paletteManager.currentPalette.getColor(at: stops[index].colorIndex) ?? .clear
                    )
                    .position(
                        x: CGFloat(stops[index].position) * barWidth,
                        y: -markerSize / 2
                    )
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                handleDrag(index: index, value: value)
                            }
                            .onEnded { value in
                                handleDragEnd(index: index, value: value)
                            }
                    )
                    .onTapGesture {
                        selectedStopIndex = index
                        showingPalettePicker = true
                    }
                }
            }
            .frame(width: barWidth, height: barHeight + markerSize)
            .padding(.top, markerSize)

            // 힌트 텍스트
            Text("Click marker: change color | Drag: move | Drag down: delete")
                .font(.system(size: 9))
                .foregroundColor(Constants.Theme.textSecondary)
        }
        .popover(isPresented: $showingPalettePicker) {
            if let index = selectedStopIndex {
                PalettePickerPopover(
                    selectedIndex: Binding(
                        get: { stops[index].colorIndex },
                        set: { newIndex in
                            stops[index] = GradientStop(position: stops[index].position, colorIndex: newIndex)
                        }
                    ),
                    paletteManager: paletteManager
                )
            }
        }
    }

    private func addStopAt(location: CGPoint) {
        guard stops.count < 8 else { return }

        let position = min(max(location.x / barWidth, 0.0), 1.0)
        let colorIndex = UInt8(0)

        stops.append(GradientStop(position: position, colorIndex: colorIndex))
        stops.sort { $0.position < $1.position }
    }

    private func handleDrag(index: Int, value: DragGesture.Value) {
        draggingIndex = index
        selectedStopIndex = index

        // 수평 위치 업데이트
        let newX = value.location.x
        let newPosition = min(max(newX / barWidth, 0.0), 1.0)

        stops[index] = GradientStop(position: newPosition, colorIndex: stops[index].colorIndex)
    }

    private func handleDragEnd(index: Int, value: DragGesture.Value) {
        draggingIndex = nil

        // 아래로 드래그하면 삭제 (최소 2개 유지)
        if value.location.y > barHeight + markerSize * 2 && stops.count > 2 {
            stops.remove(at: index)
            selectedStopIndex = nil
        } else {
            // 정렬
            stops.sort { $0.position < $1.position }
        }
    }
}

// MARK: - Gradient Stop Marker
struct GradientStopMarker: View {
    @Binding var stop: GradientStop
    let isSelected: Bool
    let color: Color

    var body: some View {
        ZStack {
            // 마커 모양 (삼각형)
            MarkerTriangle()
                .fill(isSelected ? Color.blue : Color.white)
                .frame(width: 12, height: 12)
                .overlay(
                    MarkerTriangle()
                        .stroke(Color.black, lineWidth: 1)
                )

            // 색상 프리뷰 (작은 원)
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .offset(y: -2)
        }
    }
}

// 마커용 삼각형 Shape
struct MarkerTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Color Swatch Button (팔레트에서 색상 선택)
struct ColorSwatchButton: View {
    @Binding var colorIndex: UInt8
    @ObservedObject var paletteManager: PaletteManager
    @State private var showingPalettePicker = false

    var body: some View {
        Button(action: {
            showingPalettePicker.toggle()
        }) {
            RoundedRectangle(cornerRadius: 3)
                .fill(paletteManager.currentPalette.getColor(at: colorIndex) ?? .clear)
                .frame(width: 24, height: 24)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Constants.Theme.divider, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingPalettePicker) {
            PalettePickerPopover(selectedIndex: $colorIndex, paletteManager: paletteManager)
        }
    }
}

// MARK: - Palette Picker Popover
struct PalettePickerPopover: View {
    @Binding var selectedIndex: UInt8
    @ObservedObject var paletteManager: PaletteManager

    var body: some View {
        VStack(spacing: 8) {
            Text("Select Color")
                .font(.system(size: 11, weight: .semibold))

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(24), spacing: 4), count: 8), spacing: 4) {
                ForEach(0..<min(256, paletteManager.currentPalette.count), id: \.self) { index in
                    Button(action: {
                        selectedIndex = UInt8(index)
                    }) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(paletteManager.currentPalette.getColor(at: UInt8(index)) ?? .clear)
                            .frame(width: 24, height: 24)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(selectedIndex == index ? Color.blue : Constants.Theme.divider, lineWidth: selectedIndex == index ? 2 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .frame(width: 220)
    }
}

// MARK: - Gradient Preview Bar
struct GradientPreviewBar: View {
    let stops: [GradientStop]
    @ObservedObject var paletteManager: PaletteManager

    var body: some View {
        Canvas { context, size in
            for x in 0..<Int(size.width) {
                let position = Double(x) / size.width
                let color = interpolateColor(at: position)

                let rect = CGRect(x: CGFloat(x), y: 0, width: 1, height: size.height)
                context.fill(Path(rect), with: .color(color))
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 3)
                .stroke(Constants.Theme.divider, lineWidth: 1)
        )
    }

    private func interpolateColor(at position: Double) -> Color {
        // 정렬된 stops 가정
        let sortedStops = stops.sorted { $0.position < $1.position }

        // 범위 밖
        if position <= sortedStops.first!.position {
            return paletteManager.currentPalette.getColor(at: sortedStops.first!.colorIndex) ?? .clear
        }
        if position >= sortedStops.last!.position {
            return paletteManager.currentPalette.getColor(at: sortedStops.last!.colorIndex) ?? .clear
        }

        // 두 정지점 사이 찾기
        for i in 0..<(sortedStops.count - 1) {
            let stop1 = sortedStops[i]
            let stop2 = sortedStops[i + 1]

            if position >= stop1.position && position <= stop2.position {
                let range = stop2.position - stop1.position
                let t = (position - stop1.position) / range

                guard let color1 = paletteManager.currentPalette.getColor(at: stop1.colorIndex),
                      let color2 = paletteManager.currentPalette.getColor(at: stop2.colorIndex) else {
                    return .clear
                }

                return interpolateColors(color1, color2, t: t)
            }
        }

        return .clear
    }

    private func interpolateColors(_ color1: Color, _ color2: Color, t: Double) -> Color {
        guard let rgb1 = color1.rgbComponents(),
              let rgb2 = color2.rgbComponents() else {
            return .clear
        }

        let r = rgb1.r + (rgb2.r - rgb1.r) * t
        let g = rgb1.g + (rgb2.g - rgb1.g) * t
        let b = rgb1.b + (rgb2.b - rgb1.b) * t
        let a = rgb1.a + (rgb2.a - rgb1.a) * t

        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
