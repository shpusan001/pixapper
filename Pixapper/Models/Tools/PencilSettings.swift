//
//  PencilSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI

/// 연필 도구의 설정
struct PencilSettings: ToolSettings {
    var toolType: DrawingTool { .pencil }

    /// 브러시 색상
    var color: Color = .black

    /// 브러시 크기 (픽셀 단위)
    var brushSize: Int = 1

    func copy() -> PencilSettings {
        PencilSettings(color: color, brushSize: brushSize)
    }
}
