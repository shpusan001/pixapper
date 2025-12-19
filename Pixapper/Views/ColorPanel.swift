//
//  ColorPanel.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// Adobe 스타일 컬러 패널 - 프로페셔널하고 조밀한 레이아웃
struct ColorPanel: View {
    @ObservedObject var colorManager: ColorManager
    @ObservedObject var paletteManager: PaletteManager
    @ObservedObject var pixelStateManager: PixelStateManager
    let commandManager: CommandManager

    @State private var selectedPaletteColorIndex: UInt8? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("COLOR")
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

            // Scrollable content
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Primary/Secondary Swatch
                    AdobeColorSwatchView(colorManager: colorManager)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)

                    // Recent Colors - 반응형 그리드
                    let recentColors = Array(colorManager.recentColors.prefix(20))
                    if !recentColors.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RECENT")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(Constants.Theme.textSecondary)
                                .tracking(0.3)
                                .padding(.horizontal, 6)
                                .padding(.top, 6)

                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 24, maximum: 30), spacing: 3)
                            ], spacing: 3) {
                                ForEach(Array(recentColors.enumerated()), id: \.offset) { index, color in
                                    AdobeColorCell(
                                        color: color,
                                        onTap: { colorManager.setPrimaryColor(color) },
                                        onRightClick: { colorManager.setSecondaryColor(color) }
                                    )
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                        }

                        Rectangle()
                            .fill(Constants.Theme.divider)
                            .frame(height: 1)
                    }

                    // Palette System
                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)

                    PaletteView(
                        paletteManager: paletteManager,
                        colorManager: colorManager,
                        pixelStateManager: pixelStateManager,
                        commandManager: commandManager,
                        selectedColorIndex: $selectedPaletteColorIndex
                    )

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)

                    // Palette Color Editor (선택된 색상이 있을 때만 표시)
                    if let selectedIndex = selectedPaletteColorIndex,
                       let selectedColor = paletteManager.currentPalette[selectedIndex] {
                        PaletteColorEditor(
                            colorIndex: selectedIndex,
                            color: selectedColor,
                            paletteManager: paletteManager,
                            colorManager: colorManager,
                            commandManager: commandManager,
                            onClose: { selectedPaletteColorIndex = nil }
                        )

                        Rectangle()
                            .fill(Constants.Theme.divider)
                            .frame(height: 1)
                    }

                    PaletteSelectorView(paletteManager: paletteManager)
                        .frame(maxHeight: 200)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(Constants.Theme.panelBackground)
    }
}

// MARK: - Adobe Style Components

/// Adobe 스타일 Primary/Secondary 색상 스와치
private struct AdobeColorSwatchView: View {
    @ObservedObject var colorManager: ColorManager
    @State private var showingPrimaryPicker = false
    @State private var showingSecondaryPicker = false

    var body: some View {
        HStack(spacing: 8) {
            // Primary Color (큰 사각형)
            Button(action: { showingPrimaryPicker = true }) {
                ZStack {
                    CheckerboardBackground()
                    Rectangle()
                        .fill(colorManager.primaryColor)
                }
                .frame(width: 48, height: 48)
                .overlay(
                    Rectangle()
                        .strokeBorder(Constants.Theme.textPrimary, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPrimaryPicker) {
                ColorPicker("", selection: Binding(
                    get: { colorManager.primaryColor },
                    set: { colorManager.setPrimaryColor($0) }
                ), supportsOpacity: true)
                    .labelsHidden()
                    .padding()
            }

            VStack(spacing: 4) {
                // Secondary Color (작은 사각형)
                Button(action: { showingSecondaryPicker = true }) {
                    ZStack {
                        CheckerboardBackground()
                        Rectangle()
                            .fill(colorManager.secondaryColor)
                    }
                    .frame(width: 32, height: 22)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Constants.Theme.divider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingSecondaryPicker) {
                    ColorPicker("", selection: $colorManager.secondaryColor, supportsOpacity: true)
                        .labelsHidden()
                        .padding()
                }

                // Swap & Reset buttons
                HStack(spacing: 4) {
                    // Swap button
                    Button(action: { colorManager.swapColors() }) {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 8))
                            .foregroundColor(Constants.Theme.textSecondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(1)
                    .help("Swap Colors (X)")

                    // Reset button
                    Button(action: { colorManager.resetToDefaults() }) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 8))
                            .foregroundColor(Constants.Theme.textSecondary)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.plain)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(1)
                    .help("Reset to Defaults (D)")
                }
            }

            Spacer()
        }
    }
}

/// 팔레트 색상 인라인 편집기 (HSV 색상 피커)
private struct PaletteColorEditor: View {
    let colorIndex: UInt8
    let originalColor: Color  // 원래 색상 (Cancel 시 복원용)
    @ObservedObject var paletteManager: PaletteManager
    @ObservedObject var colorManager: ColorManager
    let commandManager: CommandManager
    let onClose: () -> Void

    @State private var editingColor: Color
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var hexString: String = ""
    @State private var hasChanges: Bool = false

    init(colorIndex: UInt8, color: Color, paletteManager: PaletteManager, colorManager: ColorManager, commandManager: CommandManager, onClose: @escaping () -> Void) {
        self.colorIndex = colorIndex
        self.originalColor = color  // 원본 저장
        self.paletteManager = paletteManager
        self.colorManager = colorManager
        self.commandManager = commandManager
        self.onClose = onClose

        // 초기 색상 설정 (HSV)
        let hsv = color.hsvComponents() ?? (h: 0, s: 1, v: 1)
        _editingColor = State(initialValue: color)
        _hue = State(initialValue: hsv.h)
        _saturation = State(initialValue: hsv.s)
        _brightness = State(initialValue: hsv.v)

        let rgb = color.rgbComponents() ?? (r: 0, g: 0, b: 0, a: 1)
        _hexString = State(initialValue: String(format: "%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255)))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("EDIT COLOR #\(colorIndex)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Constants.Theme.textSecondary)
                    .tracking(0.3)

                Spacer()

                Button(action: cancelEdit) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundColor(Constants.Theme.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Cancel (ESC)")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Constants.Theme.sectionBackground)

            VStack(spacing: 8) {
                // Preview
                HStack(spacing: 8) {
                    // Original color
                    VStack(spacing: 2) {
                        ZStack {
                            CheckerboardBackground()
                            Rectangle()
                                .fill(originalColor)
                        }
                        .frame(height: 32)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Constants.Theme.divider, lineWidth: 1)
                        )
                        Text("Original")
                            .font(.system(size: 8))
                            .foregroundColor(Constants.Theme.textSecondary)
                    }

                    // Current (Live) color
                    VStack(spacing: 2) {
                        ZStack {
                            CheckerboardBackground()
                            Rectangle()
                                .fill(editingColor)
                        }
                        .frame(height: 32)
                        .overlay(
                            Rectangle()
                                .strokeBorder(Constants.Theme.divider, lineWidth: 1)
                        )
                        Text("Live")
                            .font(.system(size: 8))
                            .foregroundColor(Constants.Theme.textSecondary)
                    }
                }

                // Saturation-Brightness Square
                SaturationBrightnessSquare(
                    hue: hue,
                    saturation: $saturation,
                    brightness: $brightness,
                    onChange: { updateColorFromHSV() }
                )
                .frame(height: 120)

                // Hue Bar
                HueBar(hue: $hue, onChange: { updateColorFromHSV() })
                    .frame(height: 20)

                // Hex Input
                HStack(spacing: 4) {
                    Text("#")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(Constants.Theme.textSecondary)

                    TextField("", text: $hexString)
                        .font(.system(size: 10, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(2)
                        .onChange(of: hexString) { _, _ in
                            updateColorFromHex()
                        }
                }

                // Buttons
                HStack(spacing: 4) {
                    Button("Cancel") {
                        cancelEdit()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Constants.Theme.sectionBackground)
                    .foregroundColor(Constants.Theme.textPrimary)
                    .cornerRadius(2)

                    Spacer()

                    Button("Apply") {
                        applyColor()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Constants.Theme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(2)
                }
            }
            .padding(8)
        }
        .background(Constants.Theme.panelBackground)
        .onDisappear {
            // 편집기가 닫힐 때: 변경사항이 있으면 자동 Apply (다른 색상 클릭 시)
            // Cancel 버튼이나 ESC는 hasChanges를 false로 설정하므로 여기서 복원 안 됨
            if hasChanges {
                // 자동 Apply: Command 생성하여 Undo/Redo 스택에 추가
                let command = ChangePaletteColorCommand(
                    paletteManager: paletteManager,
                    index: colorIndex,
                    oldColor: originalColor,
                    newColor: editingColor
                )
                commandManager.performCommand(command)
            }
        }
        .onKeyPress(.escape) {
            cancelEdit()
            return .handled
        }
    }

    private func updateColorFromHSV() {
        editingColor = Color.fromHSV(h: hue, s: saturation, v: brightness)
        if let rgb = editingColor.rgbComponents() {
            hexString = String(format: "%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255))
        }

        // 실시간 미리보기: 즉시 팔레트 업데이트 (Command 없이)
        paletteManager.updateColor(at: colorIndex, to: editingColor)
        hasChanges = true

        // Primary/Secondary 동기화
        updatePrimarySecondary()
    }

    private func updateColorFromHex() {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let hexValue = Int(hex, radix: 16) else { return }

        let r = Double((hexValue >> 16) & 0xFF) / 255.0
        let g = Double((hexValue >> 8) & 0xFF) / 255.0
        let b = Double(hexValue & 0xFF) / 255.0
        editingColor = Color(red: r, green: g, blue: b)

        if let hsv = editingColor.hsvComponents() {
            hue = hsv.h
            saturation = hsv.s
            brightness = hsv.v
        }

        // 실시간 미리보기: 즉시 팔레트 업데이트 (Command 없이)
        paletteManager.updateColor(at: colorIndex, to: editingColor)
        hasChanges = true

        // Primary/Secondary 동기화
        updatePrimarySecondary()
    }

    private func updatePrimarySecondary() {
        // 원본 색상이 Primary/Secondary였다면 새 색상으로 업데이트
        if originalColor.isEqual(to: colorManager.primaryColor) {
            colorManager.primaryColor = editingColor
        }
        if originalColor.isEqual(to: colorManager.secondaryColor) {
            colorManager.secondaryColor = editingColor
        }
    }

    private func applyColor() {
        // Command 생성 및 실행 (Undo/Redo 스택에 추가)
        let command = ChangePaletteColorCommand(
            paletteManager: paletteManager,
            index: colorIndex,
            oldColor: originalColor,  // 원본 색상 사용
            newColor: editingColor
        )
        commandManager.performCommand(command)

        // 변경사항 확정됨
        hasChanges = false
        onClose()
    }

    private func cancelEdit() {
        // 원본 색상으로 복원
        restoreOriginalColor()
        hasChanges = false
        onClose()
    }

    private func restoreOriginalColor() {
        // 팔레트를 원본 색상으로 복원 (Command 없이)
        paletteManager.updateColor(at: colorIndex, to: originalColor)

        // Primary/Secondary도 복원
        if editingColor.isEqual(to: colorManager.primaryColor) {
            colorManager.primaryColor = originalColor
        }
        if editingColor.isEqual(to: colorManager.secondaryColor) {
            colorManager.secondaryColor = originalColor
        }
    }
}

/// Hue 색상 바 (무지개 그라데이션)
private struct HueBar: View {
    @Binding var hue: Double
    let onChange: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 무지개 그라데이션
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hue: 0.0, saturation: 1, brightness: 1),
                        Color(hue: 0.17, saturation: 1, brightness: 1),
                        Color(hue: 0.33, saturation: 1, brightness: 1),
                        Color(hue: 0.5, saturation: 1, brightness: 1),
                        Color(hue: 0.67, saturation: 1, brightness: 1),
                        Color(hue: 0.83, saturation: 1, brightness: 1),
                        Color(hue: 1.0, saturation: 1, brightness: 1)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(3)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Constants.Theme.divider, lineWidth: 1)
                )

                // 선택 인디케이터
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .background(Circle().fill(Color.fromHSV(h: hue, s: 1, v: 1)))
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat(hue) * (geometry.size.width - 16))
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newHue = (value.location.x / geometry.size.width).clamped(to: 0...1)
                        hue = newHue
                        onChange()
                    }
            )
        }
    }
}

/// Saturation-Brightness 2D 색상 선택 영역
private struct SaturationBrightnessSquare: View {
    let hue: Double
    @Binding var saturation: Double
    @Binding var brightness: Double
    let onChange: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 기본 색조 배경
                Rectangle()
                    .fill(Color.fromHSV(h: hue, s: 1, v: 1))

                // 흰색 → 투명 (채도)
                LinearGradient(
                    gradient: Gradient(colors: [.white, .clear]),
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // 투명 → 검정 (명도)
                LinearGradient(
                    gradient: Gradient(colors: [.clear, .black]),
                    startPoint: .top,
                    endPoint: .bottom
                )

                // 선택 인디케이터
                Circle()
                    .strokeBorder(.white, lineWidth: 2)
                    .background(
                        Circle()
                            .fill(Color.fromHSV(h: hue, s: saturation, v: brightness))
                    )
                    .frame(width: 16, height: 16)
                    .position(
                        x: CGFloat(saturation) * geometry.size.width,
                        y: (1 - CGFloat(brightness)) * geometry.size.height
                    )
            }
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(Constants.Theme.divider, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let newSaturation = (value.location.x / geometry.size.width).clamped(to: 0...1)
                        let newBrightness = 1 - (value.location.y / geometry.size.height).clamped(to: 0...1)
                        saturation = newSaturation
                        brightness = newBrightness
                        onChange()
                    }
            )
        }
    }
}

/// Adobe 스타일 색상 셀 (Recent용) - 반응형
private struct AdobeColorCell: View {
    let color: Color
    let onTap: () -> Void
    let onRightClick: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            CheckerboardBackground()
            Rectangle()
                .fill(color)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .overlay(
            Rectangle()
                .strokeBorder(
                    isHovered ? Constants.Theme.accentBlue : Constants.Theme.divider,
                    lineWidth: isHovered ? 1.5 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .simultaneousGesture(
            TapGesture()
                .modifiers(.control)
                .onEnded { _ in onRightClick() }
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// Adobe 스타일 팔레트 셀 (편집 가능)
private struct AdobePaletteCell: View {
    let color: Color
    let index: Int
    @ObservedObject var colorManager: ColorManager

    @State private var isHovered = false
    @State private var showingColorPicker = false
    @State private var editingColor: Color

    init(color: Color, index: Int, colorManager: ColorManager) {
        self.color = color
        self.index = index
        self.colorManager = colorManager
        self._editingColor = State(initialValue: color)
    }

    var body: some View {
        ZStack {
            CheckerboardBackground()
            Rectangle()
                .fill(color)
        }
        .aspectRatio(1.0, contentMode: .fit)
        .overlay(
            Rectangle()
                .strokeBorder(
                    isHovered ? Constants.Theme.accentBlue : Constants.Theme.divider,
                    lineWidth: isHovered ? 1.5 : 0.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            colorManager.setPrimaryColor(color)
        }
        .onTapGesture(count: 2) {
            editingColor = color
            showingColorPicker = true
        }
        .simultaneousGesture(
            TapGesture()
                .modifiers(.control)
                .onEnded { _ in
                    colorManager.setSecondaryColor(color)
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            Button("Set as Primary") {
                colorManager.setPrimaryColor(color)
            }
            Button("Set as Secondary") {
                colorManager.setSecondaryColor(color)
            }
            Button("Edit Color...") {
                editingColor = color
                showingColorPicker = true
            }
            Divider()
            Button("Remove", role: .destructive) {
                colorManager.removeFromPalette(at: index)
            }
        }
        .popover(isPresented: $showingColorPicker) {
            VStack(spacing: 8) {
                Text("Edit Color")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Constants.Theme.textPrimary)

                ColorPicker("", selection: $editingColor, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 140, height: 140)

                HStack(spacing: 4) {
                    Button("Cancel") {
                        showingColorPicker = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Constants.Theme.sectionBackground)
                    .foregroundColor(Constants.Theme.textPrimary)
                    .cornerRadius(2)

                    Button("Done") {
                        colorManager.updatePalette(at: index, with: editingColor)
                        showingColorPicker = false
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Constants.Theme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(2)
                }
            }
            .padding(12)
            .frame(width: 180)
            .background(Constants.Theme.panelBackground)
        }
    }
}
