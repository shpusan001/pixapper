//
//  FillSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI

/// 채우기 타입
enum FillType: String, Codable, CaseIterable {
    case solid      // 단색
    case linear     // 선형 그래디언트
    case radial     // 방사형 그래디언트
}

/// 채우기 도구의 설정
struct FillSettings: ToolSettings {
    var toolType: DrawingTool { .fill }

    /// 색상 허용 오차 (0.0 ~ 1.0, 완전히 같은 색만 채우기 ~ 비슷한 색도 채우기)
    var tolerance: Double = 0.0

    /// 채우기 타입 (단색 vs 그래디언트)
    var fillType: FillType = .solid

    // MARK: - 그래디언트 설정

    /// 선형 그래디언트 드래그 시작점
    var linearStartX: Int = 0
    var linearStartY: Int = 0

    /// 선형 그래디언트 드래그 끝점
    var linearEndX: Int = 0
    var linearEndY: Int = 0

    /// 방사형 그래디언트 중심점 (픽셀 좌표)
    var radialCenterX: Int = 0
    var radialCenterY: Int = 0

    /// 방사형 그래디언트 반경 (픽셀 단위)
    var radialRadius: Double = 0

    func copy() -> FillSettings {
        var copy = FillSettings(
            tolerance: tolerance,
            fillType: fillType
        )
        copy.linearStartX = linearStartX
        copy.linearStartY = linearStartY
        copy.linearEndX = linearEndX
        copy.linearEndY = linearEndY
        copy.radialCenterX = radialCenterX
        copy.radialCenterY = radialCenterY
        copy.radialRadius = radialRadius
        return copy
    }
}
