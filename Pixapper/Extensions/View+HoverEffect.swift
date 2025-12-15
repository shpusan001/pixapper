//
//  View+HoverEffect.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

extension View {
    /// 호버 시 배경 효과를 추가하는 Modifier
    /// - Parameters:
    ///   - cornerRadius: 배경의 둥근 모서리 반경 (기본값: 3)
    ///   - hoverColor: 호버 시 표시할 색상 (기본값: Constants.Theme.hoverBackground)
    /// - Returns: 호버 효과가 적용된 View
    func hoverEffect(
        cornerRadius: CGFloat = 3,
        hoverColor: Color = Constants.Theme.hoverBackground
    ) -> some View {
        modifier(HoverEffectModifier(cornerRadius: cornerRadius, hoverColor: hoverColor))
    }
}

private struct HoverEffectModifier: ViewModifier {
    let cornerRadius: CGFloat
    let hoverColor: Color
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isHovered ? hoverColor : Color.clear)
            )
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
