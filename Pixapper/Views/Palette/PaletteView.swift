//
//  PaletteView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

/// 팔레트 색상 그리드 뷰
struct PaletteView: View {
    @ObservedObject var paletteManager: PaletteManager
    @ObservedObject var colorManager: ColorManager
    @ObservedObject var pixelStateManager: PixelStateManager
    let commandManager: CommandManager
    @Binding var selectedColorIndex: UInt8?
    @Binding var originalSelectedColor: Color?

    @State private var showingAddColorPicker = false
    @State private var newColor: Color = .white

    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 2), count: 8)

    // Color usage data
    private var colorUsage: [UInt8: Int] {
        pixelStateManager.getColorUsage()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Palette: \(paletteManager.currentPalette.name)")
                    .font(.system(size: Constants.Layout.Header.fontSize, weight: .semibold))
                    .foregroundColor(Constants.Theme.textPrimary)

                Spacer()

                Text("\(paletteManager.currentPalette.count)/256")
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Theme.textSecondary)

                // Add Color button
                Button(action: {
                    newColor = colorManager.primaryColor
                    showingAddColorPicker = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Constants.Theme.textPrimary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help("Add Color to Palette")
                .hoverEffect(cornerRadius: Constants.Layout.Button.cornerRadius)
                .disabled(paletteManager.currentPalette.count >= 256)
            }
            .padding(.horizontal, 10)
            .frame(height: Constants.Layout.Header.standardHeight)
            .background(Constants.Theme.sectionBackground)

            Divider()

            // Color Grid
            ScrollView {
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<paletteManager.currentPalette.count, id: \.self) { index in
                        if let color = paletteManager.currentPalette[UInt8(index)] {
                            PaletteGridCell(
                                color: color,
                                index: UInt8(index),
                                isSelected: selectedColorIndex == UInt8(index),
                                isPrimary: color.isEqual(to: colorManager.primaryColor),
                                isSecondary: color.isEqual(to: colorManager.secondaryColor),
                                usageCount: colorUsage[UInt8(index)] ?? 0,
                                onTap: {
                                    // 색상 선택 (편집기 표시)
                                    selectedColorIndex = UInt8(index)
                                    originalSelectedColor = color  // 원본 색상 캡처
                                    colorManager.primaryColor = color
                                },
                                onRemove: {
                                    paletteManager.removeColor(at: UInt8(index))
                                }
                            )
                        }
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
        .background(Constants.Theme.panelBackground)
        .sheet(isPresented: $showingAddColorPicker) {
            ColorPickerSheet(
                color: $newColor,
                onSave: { color in
                    _ = paletteManager.addColor(color)
                }
            )
        }
    }
}

/// 개별 색상 셀
struct PaletteGridCell: View {
    let color: Color
    let index: UInt8
    let isSelected: Bool
    let isPrimary: Bool
    let isSecondary: Bool
    let usageCount: Int
    let onTap: () -> Void
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        ZStack {
            CheckerboardBackground()
            Rectangle()
                .fill(color)
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay(
            Rectangle()
                .strokeBorder(borderColor, lineWidth: borderWidth)
        )
        .overlay(
                // Primary/Secondary indicators
                ZStack {
                    if isPrimary {
                        CornerTriangle(corner: .topLeft)
                            .fill(color.contrastColor())
                    }
                    if isSecondary {
                        CornerTriangle(corner: .bottomRight)
                            .fill(color.contrastColor())
                    }
                }
            )
            .help("Index: \(index) | Used: \(usageCount) pixels")
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                onTap()
            }
            .contextMenu {
                Button("Remove from Palette", role: .destructive) {
                    onRemove()
                }
            }
    }

    private var borderColor: Color {
        if isSelected {
            return Constants.Theme.accentBlue
        } else if isHovered {
            return Color.white.opacity(0.5)
        } else {
            return Color.gray.opacity(0.3)
        }
    }

    private var borderWidth: CGFloat {
        isSelected ? 2 : 1
    }
}

/// 색상 피커 시트
struct ColorPickerSheet: View {
    @Binding var color: Color
    let onSave: (Color) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Color")
                .font(.headline)

            ColorPicker("Select Color", selection: $color, supportsOpacity: false)
                .labelsHidden()

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Save") {
                    onSave(color)
                    dismiss()
                }
                .keyboardShortcut(.return)
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
}

// MARK: - Corner Triangle Shape

/// 모서리 삼각형 (Primary/Secondary 표시용)
struct CornerTriangle: Shape {
    enum Corner {
        case topLeft
        case bottomRight
    }

    let corner: Corner

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let size: CGFloat = min(rect.width, rect.height) * 0.35 // 셀 크기의 35%

        switch corner {
        case .topLeft:
            // 왼쪽 위 삼각형
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX + size, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + size))
            path.closeSubpath()

        case .bottomRight:
            // 오른쪽 아래 삼각형
            path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX - size, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - size))
            path.closeSubpath()
        }

        return path
    }
}
