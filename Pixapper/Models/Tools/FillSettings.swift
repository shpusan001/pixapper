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

    /// 그라디언트 색상 정지점 (Multi-stop gradient)
    var gradientStops: [GradientStop] = [
        GradientStop(position: 0.0, colorIndex: 0),  // 시작색
        GradientStop(position: 1.0, colorIndex: 1)   // 끝색
    ]

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
        var copy = FillSettings()
        copy.tolerance = tolerance
        copy.fillType = fillType
        copy.gradientStops = gradientStops
        copy.linearStartX = linearStartX
        copy.linearStartY = linearStartY
        copy.linearEndX = linearEndX
        copy.linearEndY = linearEndY
        copy.radialCenterX = radialCenterX
        copy.radialCenterY = radialCenterY
        copy.radialRadius = radialRadius
        return copy
    }

    // MARK: - Gradient Stop Helpers

    /// 주어진 position을 감싸는 두 stop을 찾아 반환
    /// - Parameter position: 0.0 ~ 1.0 범위의 위치
    /// - Returns: (하위 stop, 상위 stop, 보간 비율 t)
    func findSurroundingStops(at position: Double) -> (lower: GradientStop, upper: GradientStop, t: Double) {
        // gradientStops는 position 기준 정렬되어 있어야 함
        let sortedStops = gradientStops.sorted { $0.position < $1.position }

        // position이 범위 밖이면 양 끝 stop 사용
        if position <= sortedStops.first!.position {
            let first = sortedStops.first!
            return (first, first, 0.0)
        }
        if position >= sortedStops.last!.position {
            let last = sortedStops.last!
            return (last, last, 1.0)
        }

        // position을 감싸는 두 stop 찾기
        for i in 0..<(sortedStops.count - 1) {
            let lower = sortedStops[i]
            let upper = sortedStops[i + 1]

            if position >= lower.position && position <= upper.position {
                // 보간 비율 계산 (0.0 = lower, 1.0 = upper)
                let range = upper.position - lower.position
                let t = range > 0 ? (position - lower.position) / range : 0.0
                return (lower, upper, t)
            }
        }

        // 여기 도달하면 안되지만, fallback
        let first = sortedStops.first!
        let last = sortedStops.last!
        return (first, last, 0.5)
    }

    /// Stop들을 균등 간격으로 재배치
    mutating func distributeStopsEvenly() {
        guard gradientStops.count > 2 else { return }

        var sortedStops = gradientStops.sorted { $0.position < $1.position }
        let step = 1.0 / Double(sortedStops.count - 1)

        for i in 0..<sortedStops.count {
            sortedStops[i] = GradientStop(
                id: sortedStops[i].id,
                position: Double(i) * step,
                colorIndex: sortedStops[i].colorIndex
            )
        }

        gradientStops = sortedStops
    }

    /// 그라데이션 방향 반전 (stop 순서 뒤집기)
    mutating func reverseGradient() {
        gradientStops = gradientStops.map { stop in
            GradientStop(
                id: stop.id,
                position: 1.0 - stop.position,
                colorIndex: stop.colorIndex
            )
        }
    }

    // MARK: - Gradient Presets

    /// 프리셋 그라데이션 적용
    mutating func applyPreset(_ preset: GradientPreset) {
        gradientStops = preset.stops
    }
}

// MARK: - Gradient Presets

enum GradientPreset: String, CaseIterable, Identifiable {
    case rainbow = "Rainbow"
    case fire = "Fire"
    case ocean = "Ocean"
    case sunset = "Sunset"
    case forest = "Forest"

    var id: String { rawValue }

    var stops: [GradientStop] {
        switch self {
        case .rainbow:
            return [
                GradientStop(position: 0.0, colorIndex: 0),   // Red
                GradientStop(position: 0.17, colorIndex: 1),  // Orange
                GradientStop(position: 0.33, colorIndex: 2),  // Yellow
                GradientStop(position: 0.5, colorIndex: 3),   // Green
                GradientStop(position: 0.67, colorIndex: 4),  // Blue
                GradientStop(position: 0.83, colorIndex: 5),  // Indigo
                GradientStop(position: 1.0, colorIndex: 6)    // Violet
            ]
        case .fire:
            return [
                GradientStop(position: 0.0, colorIndex: 0),   // Dark red
                GradientStop(position: 0.5, colorIndex: 1),   // Orange
                GradientStop(position: 1.0, colorIndex: 2)    // Yellow
            ]
        case .ocean:
            return [
                GradientStop(position: 0.0, colorIndex: 3),   // Dark blue
                GradientStop(position: 0.5, colorIndex: 4),   // Cyan
                GradientStop(position: 1.0, colorIndex: 5)    // Light blue/White
            ]
        case .sunset:
            return [
                GradientStop(position: 0.0, colorIndex: 6),   // Purple
                GradientStop(position: 0.5, colorIndex: 7),   // Pink
                GradientStop(position: 1.0, colorIndex: 8)    // Orange
            ]
        case .forest:
            return [
                GradientStop(position: 0.0, colorIndex: 9),   // Dark green
                GradientStop(position: 0.5, colorIndex: 10),  // Green
                GradientStop(position: 1.0, colorIndex: 11)   // Light green
            ]
        }
    }
}
