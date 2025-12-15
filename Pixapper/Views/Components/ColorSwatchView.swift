//
//  ColorSwatchView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// Primary/Secondary 색상을 표시하고 선택할 수 있는 컴포넌트 (Adobe Photoshop 스타일)
struct ColorSwatchView: View {
    @ObservedObject var colorManager: ColorManager

    @State private var showingPrimaryPicker = false
    @State private var showingSecondaryPicker = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Secondary 색상 (오른쪽 아래)
            Button(action: {
                showingSecondaryPicker = true
            }) {
                Rectangle()
                    .fill(colorManager.secondaryColor)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Constants.Theme.divider, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .offset(x: 14, y: 14)
            .popover(isPresented: $showingSecondaryPicker) {
                ColorPicker("Secondary Color", selection: $colorManager.secondaryColor, supportsOpacity: true)
                    .labelsHidden()
                    .padding()
            }

            // Primary 색상 (왼쪽 위)
            Button(action: {
                showingPrimaryPicker = true
            }) {
                Rectangle()
                    .fill(colorManager.primaryColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Constants.Theme.textPrimary, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showingPrimaryPicker) {
                ColorPicker("Primary Color", selection: Binding(
                    get: { colorManager.primaryColor },
                    set: { colorManager.setPrimaryColor($0) }
                ), supportsOpacity: true)
                    .labelsHidden()
                    .padding()
            }

            // Swap 버튼 (오른쪽 위 작은 화살표)
            Button(action: {
                colorManager.swapColors()
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 8))
                    .foregroundColor(Constants.Theme.textSecondary)
                    .frame(width: 12, height: 12)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(1)
            }
            .buttonStyle(.plain)
            .offset(x: 26, y: -2)
            .help("Swap Colors (X)")
        }
        .frame(width: 40, height: 40)
    }
}

/// 컴팩트한 색상 Swatch (ToolPanel용)
struct CompactColorSwatchView: View {
    @ObservedObject var colorManager: ColorManager

    @State private var showingPrimaryPicker = false
    @State private var showingSecondaryPicker = false

    var body: some View {
        VStack(spacing: 4) {
            // Primary/Secondary 겹친 형태
            ZStack(alignment: .bottomTrailing) {
                // Primary 색상
                Button(action: {
                    showingPrimaryPicker = true
                }) {
                    ZStack {
                        // 체크보드 배경 (투명도 표시용)
                        checkerboardBackground

                        Rectangle()
                            .fill(colorManager.primaryColor)
                    }
                    .frame(width: 36, height: 36)
                    .overlay(
                        Rectangle()
                            .strokeBorder(Constants.Theme.textPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingPrimaryPicker) {
                    ColorPicker("Primary Color", selection: Binding(
                        get: { colorManager.primaryColor },
                        set: { colorManager.setPrimaryColor($0) }
                    ), supportsOpacity: true)
                        .labelsHidden()
                        .padding()
                }

                // Secondary 색상 (오른쪽 아래 작은 사각형) - 클릭하면 교체
                Button(action: {
                    colorManager.swapColors()
                }) {
                    ZStack {
                        // 체크보드 배경
                        checkerboardBackground
                            .frame(width: 16, height: 16)

                        Rectangle()
                            .fill(colorManager.secondaryColor)
                            .frame(width: 16, height: 16)
                    }
                    .overlay(
                        Rectangle()
                            .strokeBorder(Constants.Theme.textPrimary, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: 2)
                .help("Click to swap colors")
            }
        }
    }

    private var checkerboardBackground: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let squareSize: CGFloat = 4
                let columns = Int(ceil(size.width / squareSize))
                let rows = Int(ceil(size.height / squareSize))

                for row in 0..<rows {
                    for col in 0..<columns {
                        let isLight = (row + col) % 2 == 0
                        let color = isLight ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}
