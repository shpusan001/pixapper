//
//  RecentColorsView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// 최근 사용한 색상 목록을 표시하는 컴포넌트
struct RecentColorsView: View {
    @ObservedObject var colorManager: ColorManager

    private let colorSize: CGFloat = Constants.Layout.UI.ColorSwatch.cellSize
    private let spacing: CGFloat = Constants.Layout.UI.ColorSwatch.spacing

    var body: some View {
        GeometryReader { geometry in
            let availableWidth = geometry.size.width
            let maxColors = max(1, Int((availableWidth + spacing) / (colorSize + spacing)))
            let displayCount = min(maxColors, colorManager.recentColors.count)

            HStack(spacing: spacing) {
                ForEach(0..<displayCount, id: \.self) { index in
                    ColorCell(
                        color: colorManager.recentColors[index],
                        onTap: {
                            colorManager.setPrimaryColor(colorManager.recentColors[index])
                        },
                        onRightClick: {
                            colorManager.setSecondaryColor(colorManager.recentColors[index])
                        }
                    )
                }

                if colorManager.recentColors.isEmpty {
                    Text("No recent colors")
                        .font(.system(size: 10))
                        .foregroundColor(Constants.Theme.textSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
        }
        .frame(height: colorSize)
    }
}

/// 개별 색상 셀
private struct ColorCell: View {
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
        .frame(width: 24, height: 24)
        .cornerRadius(2)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(
                    isHovered ? Constants.Theme.accentBlue : Constants.Theme.divider,
                    lineWidth: isHovered ? 2 : 1
                )
        )
        .onTapGesture {
            onTap()
        }
        .onTapGesture(count: 1, perform: {}) // 우클릭 구현을 위한 더미
        .simultaneousGesture(
            TapGesture(count: 1)
                .modifiers(.control) // Ctrl+Click = 우클릭 (macOS)
                .onEnded { _ in
                    onRightClick()
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .help("Click: Set Primary | Ctrl+Click: Set Secondary")
    }
}
