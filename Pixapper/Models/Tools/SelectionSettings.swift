//
//  SelectionSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 선택 방식
enum SelectionType: String, CaseIterable, Identifiable {
    case rectangle = "Rectangle"
    case freeform = "Freeform"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rectangle:
            return "Rectangle"
        case .freeform:
            return "Freeform (Lasso)"
        }
    }

    var icon: String {
        switch self {
        case .rectangle:
            return "rectangle.dashed"
        case .freeform:
            return "lasso"
        }
    }
}

/// 선택 도구의 설정
struct SelectionSettings: ToolSettings {
    var toolType: DrawingTool { .selection }

    /// 선택 방식
    var selectionType: SelectionType = .rectangle

    func copy() -> SelectionSettings {
        var copy = SelectionSettings()
        copy.selectionType = selectionType
        return copy
    }
}
