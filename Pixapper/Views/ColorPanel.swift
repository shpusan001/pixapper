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
    @State private var originalSelectedColor: Color? = nil  // 편집 시작 시 색상 캡처

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("COLOR")
                    .font(.system(size: Constants.Layout.Header.fontSize, weight: .semibold))
                    .foregroundColor(Constants.Theme.textPrimary)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.horizontal, 10)
            .frame(height: Constants.Layout.Header.standardHeight)
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

                    PaletteView(
                        paletteManager: paletteManager,
                        colorManager: colorManager,
                        pixelStateManager: pixelStateManager,
                        commandManager: commandManager,
                        selectedColorIndex: $selectedPaletteColorIndex,
                        originalSelectedColor: $originalSelectedColor
                    )

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)

                    // Palette Color Editor (선택된 색상이 있을 때만 표시)
                    if let selectedIndex = selectedPaletteColorIndex,
                       let originalColor = originalSelectedColor {
                        PaletteColorEditor(
                            colorIndex: selectedIndex,
                            originalColor: originalColor,
                            paletteManager: paletteManager,
                            colorManager: colorManager,
                            commandManager: commandManager,
                            onClose: {
                                selectedPaletteColorIndex = nil
                                originalSelectedColor = nil
                            }
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

/// 컴팩트 Primary/Secondary 색상 스와치
private struct AdobeColorSwatchView: View {
    @ObservedObject var colorManager: ColorManager

    var body: some View {
        HStack(spacing: 6) {
            // Primary Color (32x32)
            ZStack {
                CheckerboardBackground()
                Rectangle()
                    .fill(colorManager.primaryColor)
            }
            .frame(width: 32, height: 32)
            .overlay(
                Rectangle()
                    .strokeBorder(Constants.Theme.textPrimary, lineWidth: 1)
            )
            .help("Primary Color")

            // Secondary Color (20x20)
            ZStack {
                CheckerboardBackground()
                Rectangle()
                    .fill(colorManager.secondaryColor)
            }
            .frame(width: 20, height: 20)
            .overlay(
                Rectangle()
                    .strokeBorder(Constants.Theme.divider, lineWidth: 1)
            )
            .help("Secondary Color")

            // Swap button
            Button(action: { colorManager.swapColors() }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 9))
                    .foregroundColor(Constants.Theme.textSecondary)
                    .frame(width: 16, height: 16)
            }
            .buttonStyle(.plain)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(2)
            .help("Swap Colors (X)")

            Spacer()
        }
    }
}

/// 팔레트 색상 인라인 편집기 (HSV 색상 피커) - Apply/Cancel 방식
private struct PaletteColorEditor: View {
    let colorIndex: UInt8
    @ObservedObject var paletteManager: PaletteManager
    @ObservedObject var colorManager: ColorManager
    let commandManager: CommandManager
    let onClose: () -> Void

    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    @State private var brightness: Double = 1
    @State private var alpha: Double = 1
    @State private var hexString: String = ""
    @State private var editingColor: Color  // 임시 편집 색상 (팔레트 업데이트 안함)
    private let originalColor: Color  // 편집 시작 시 색상

    init(colorIndex: UInt8, originalColor: Color, paletteManager: PaletteManager, colorManager: ColorManager, commandManager: CommandManager, onClose: @escaping () -> Void) {
        self.colorIndex = colorIndex
        self.paletteManager = paletteManager
        self.colorManager = colorManager
        self.commandManager = commandManager
        self.onClose = onClose
        self.originalColor = originalColor

        // 초기 색상 설정 (HSV + Alpha)
        let hsv = originalColor.hsvComponents() ?? (h: 0, s: 1, v: 1)
        _hue = State(initialValue: hsv.h)
        _saturation = State(initialValue: hsv.s)
        _brightness = State(initialValue: hsv.v)

        let rgb = originalColor.rgbComponents() ?? (r: 0, g: 0, b: 0, a: 1)
        _alpha = State(initialValue: rgb.a)
        _hexString = State(initialValue: String(format: "%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255)))

        _editingColor = State(initialValue: originalColor)
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

                Button(action: { cancelEdit() }) {
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
                // Preview - 이중 프리뷰 (Original vs Live)
                HStack(spacing: 8) {
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
                HueBar(
                    hue: $hue,
                    onChange: { updateColorFromHSV() }
                )
                .frame(height: 20)

                // Alpha Slider
                VStack(spacing: 4) {
                    HStack(spacing: 4) {
                        Text("Alpha")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Constants.Theme.textSecondary)
                            .frame(width: 35, alignment: .leading)

                        Slider(value: $alpha, in: 0...1)
                            .tint(Constants.Theme.accentBlue)
                            .onChange(of: alpha) { _, _ in
                                updateColorFromHSV()
                            }

                        Text("\(Int(alpha * 100))%")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                            .frame(width: 35, alignment: .trailing)
                    }
                    .frame(height: 20)
                }

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

                // Apply/Cancel Buttons
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
        .onKeyPress(.escape) {
            cancelEdit()
            return .handled
        }
    }

    private func updateColorFromHSV() {
        // 편집 색상 업데이트 (HSV + Alpha)
        let baseColor = Color.fromHSV(h: hue, s: saturation, v: brightness)
        editingColor = baseColor.opacity(alpha)

        // 실시간 캔버스 반영: 팔레트 즉시 업데이트 (Command 없이)
        paletteManager.updateColor(at: colorIndex, to: editingColor)

        // Hex 필드 동기화 (RGB만, 알파는 슬라이더로 별도 관리)
        if let rgb = editingColor.rgbComponents() {
            hexString = String(format: "%02X%02X%02X", Int(rgb.r * 255), Int(rgb.g * 255), Int(rgb.b * 255))
        }

        // Primary/Secondary 동기화 (실시간)
        updatePrimarySecondary()
    }

    private func updateColorFromHex() {
        let hex = hexString.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6,
              let hexValue = Int(hex, radix: 16) else { return }

        let r = Double((hexValue >> 16) & 0xFF) / 255.0
        let g = Double((hexValue >> 8) & 0xFF) / 255.0
        let b = Double(hexValue & 0xFF) / 255.0

        // 편집 색상 업데이트 (현재 알파값 유지)
        editingColor = Color(red: r, green: g, blue: b).opacity(alpha)

        // 실시간 캔버스 반영: 팔레트 즉시 업데이트 (Command 없이)
        paletteManager.updateColor(at: colorIndex, to: editingColor)

        // HSV 동기화
        let baseColor = Color(red: r, green: g, blue: b)
        if let hsv = baseColor.hsvComponents() {
            hue = hsv.h
            saturation = hsv.s
            brightness = hsv.v
        }

        // Primary/Secondary 동기화 (실시간)
        updatePrimarySecondary()
    }

    private func updatePrimarySecondary() {
        // 원본 색상이 Primary/Secondary였다면 실시간 업데이트
        if originalColor.isEqual(to: colorManager.primaryColor) {
            colorManager.primaryColor = editingColor
        }
        if originalColor.isEqual(to: colorManager.secondaryColor) {
            colorManager.secondaryColor = editingColor
        }
    }

    private func applyColor() {
        // 변경사항이 있을 때만 Command 생성
        if !originalColor.isEqual(to: editingColor) {
            let command = ChangePaletteColorCommand(
                paletteManager: paletteManager,
                index: colorIndex,
                oldColor: originalColor,
                newColor: editingColor
            )
            commandManager.performCommand(command)
        }

        onClose()
    }

    private func cancelEdit() {
        // 원본 색상으로 복원 (Command 없이)
        paletteManager.updateColor(at: colorIndex, to: originalColor)

        // Primary/Secondary 복원
        if editingColor.isEqual(to: colorManager.primaryColor) {
            colorManager.primaryColor = originalColor
        }
        if editingColor.isEqual(to: colorManager.secondaryColor) {
            colorManager.secondaryColor = originalColor
        }

        onClose()
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
