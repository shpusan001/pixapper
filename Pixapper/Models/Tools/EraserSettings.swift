//
//  EraserSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 지우개 도구의 설정
struct EraserSettings: ToolSettings {
    var toolType: DrawingTool { .eraser }

    /// 지우개 크기 (픽셀 단위)
    var brushSize: Int = 1

    func copy() -> EraserSettings {
        EraserSettings(brushSize: brushSize)
    }
}
