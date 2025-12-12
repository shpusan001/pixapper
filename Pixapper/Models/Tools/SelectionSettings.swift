//
//  SelectionSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 선택 도구의 설정
struct SelectionSettings: ToolSettings {
    var toolType: DrawingTool { .selection }

    func copy() -> SelectionSettings {
        SelectionSettings()
    }
}
