//
//  FillSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI

/// 채우기 도구의 설정
struct FillSettings: ToolSettings {
    var toolType: DrawingTool { .fill }

    /// 채우기 색상
    var color: Color = .black

    /// 색상 허용 오차 (0.0 ~ 1.0, 완전히 같은 색만 채우기 ~ 비슷한 색도 채우기)
    var tolerance: Double = 0.0

    func copy() -> FillSettings {
        FillSettings(color: color, tolerance: tolerance)
    }
}
