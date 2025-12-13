//
//  ToolSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI

/// 모든 도구 설정이 구현해야 하는 기본 프로토콜
protocol ToolSettings {
    /// 도구 타입
    var toolType: DrawingTool { get }

    /// 설정의 복사본을 생성합니다
    func copy() -> Self
}

/// 그리기 도구 타입
enum DrawingTool: String, CaseIterable, Identifiable {
    case pencil
    case eraser
    case fill
    case rectangle
    case circle
    case line
    case selection

    var id: String { rawValue }

    /// 도구 이름 (UI 표시용)
    var displayName: String {
        switch self {
        case .pencil: return "Pencil"
        case .eraser: return "Eraser"
        case .fill: return "Fill"
        case .rectangle: return "Rectangle"
        case .circle: return "Circle"
        case .line: return "Line"
        case .selection: return "Selection"
        }
    }
}
