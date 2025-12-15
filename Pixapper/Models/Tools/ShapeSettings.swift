//
//  ShapeSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI

/// 도형 도구(사각형, 원, 선)의 설정
struct ShapeSettings: ToolSettings {
    /// 도형 타입 (rectangle, circle, line)
    let toolType: DrawingTool

    /// 선 굵기 (픽셀 단위)
    var strokeWidth: Int = 1

    /// 도형 채우기 여부
    var isFilled: Bool = false

    func copy() -> ShapeSettings {
        ShapeSettings(
            toolType: toolType,
            strokeWidth: strokeWidth,
            isFilled: isFilled
        )
    }
}
