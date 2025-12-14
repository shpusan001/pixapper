//
//  DitheringSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI

/// 디더링 브러시 도구 설정
struct DitheringSettings: ToolSettings {
    var toolType: DrawingTool { .dithering }

    /// 기본 색상
    var color: Color = .black

    /// 보조 색상 (패턴에서 교차로 사용)
    var secondaryColor: Color = .white

    /// 브러시 크기
    var brushSize: Int = 3

    /// 디더링 패턴
    var pattern: DitheringPattern = .checkerboard

    /// 패턴 밀도 (0.0 ~ 1.0)
    var density: Double = 0.5

    /// 커스텀 패턴 그리드 크기
    var customPatternSize: Int = 8

    /// 커스텀 패턴 (동적 크기, true = color1, false = color2)
    var customPattern: [[Bool]] = Array(repeating: Array(repeating: true, count: 8), count: 8)

    func copy() -> DitheringSettings {
        return self
    }

    /// 커스텀 패턴 크기 변경 (기존 패턴은 유지하고 크기만 조정)
    mutating func resizeCustomPattern(newSize: Int) {
        guard newSize > 0 && newSize <= 16 else { return }

        var newPattern: [[Bool]] = Array(repeating: Array(repeating: true, count: newSize), count: newSize)

        // 기존 패턴을 새 크기에 맞게 복사 (좌상단부터)
        let minSize = min(customPatternSize, newSize)
        for y in 0..<minSize {
            for x in 0..<minSize {
                if y < customPattern.count && x < customPattern[y].count {
                    newPattern[y][x] = customPattern[y][x]
                }
            }
        }

        customPatternSize = newSize
        customPattern = newPattern
    }
}

/// 디더링 패턴 타입
enum DitheringPattern: String, CaseIterable, Identifiable {
    case checkerboard  // 체커보드 (대각선 / 방향)
    case dots          // 점 패턴 (25%)
    case horizontal    // 수평 줄무늬
    case vertical      // 수직 줄무늬
    case crosshatch    // 크로스 해치 패턴
    case sparse        // 드문 점 패턴
    case custom        // 커스텀 패턴

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .checkerboard: return "Checkerboard"
        case .dots: return "Dots"
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .crosshatch: return "Crosshatch"
        case .sparse: return "Sparse"
        case .custom: return "Custom"
        }
    }
}
