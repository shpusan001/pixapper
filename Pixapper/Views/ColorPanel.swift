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
                        commandManager: commandManager
                    )

                    Rectangle()
                        .fill(Constants.Theme.divider)
                        .frame(height: 1)

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
