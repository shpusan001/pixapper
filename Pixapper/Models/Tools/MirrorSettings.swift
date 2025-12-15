//
//  MirrorSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI

/// 대칭 그리기 도구 설정
struct MirrorSettings: ToolSettings {
    var toolType: DrawingTool { .mirror }

    /// 브러시 크기
    var brushSize: Int = 1

    /// 대칭 모드
    var mode: MirrorMode = .horizontal

    /// 대칭 축 위치 (0.0 ~ 1.0, 캔버스 너비/높이 기준)
    var axisPosition: Double = 0.5

    func copy() -> MirrorSettings {
        return self
    }
}

/// 대칭 모드
enum MirrorMode: String, CaseIterable, Identifiable {
    case horizontal  // 좌우 대칭
    case vertical    // 상하 대칭
    case both        // 양방향 대칭 (4분할)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .both: return "Both"
        }
    }
}
