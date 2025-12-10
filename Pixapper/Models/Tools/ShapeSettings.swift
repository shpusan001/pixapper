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

    /// 선 색상
    var strokeColor: Color = .black

    /// 선 굵기 (픽셀 단위)
    var strokeWidth: Int = 1

    /// 채우기 색상 (nil이면 채우지 않음)
    var fillColor: Color? = nil

    func copy() -> ShapeSettings {
        ShapeSettings(
            toolType: toolType,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            fillColor: fillColor
        )
    }
}
