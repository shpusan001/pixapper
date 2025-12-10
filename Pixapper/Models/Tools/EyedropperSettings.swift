//
//  EyedropperSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// 스포이트 도구의 설정
/// (특별한 설정이 필요 없지만 일관성을 위해 정의)
struct EyedropperSettings: ToolSettings {
    var toolType: DrawingTool { .eyedropper }

    func copy() -> EyedropperSettings {
        EyedropperSettings()
    }
}
