//
//  ToolSettingsManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI
import Combine

/// 각 도구의 설정을 관리하는 중앙 관리자
class ToolSettingsManager: ObservableObject {
    /// 현재 선택된 도구
    @Published var selectedTool: DrawingTool = .pencil

    /// 연필 설정
    @Published var pencilSettings = PencilSettings()

    /// 지우개 설정
    @Published var eraserSettings = EraserSettings()

    /// 사각형 설정
    @Published var rectangleSettings = ShapeSettings(toolType: .rectangle)

    /// 원 설정
    @Published var circleSettings = ShapeSettings(toolType: .circle)

    /// 선 설정
    @Published var lineSettings = ShapeSettings(toolType: .line)

    /// 채우기 설정
    @Published var fillSettings = FillSettings()

    /// 스포이트 설정
    @Published var eyedropperSettings = EyedropperSettings()

    /// 현재 선택된 도구의 기본 색상 (UI 표시용)
    var currentColor: Color {
        get {
            switch selectedTool {
            case .pencil:
                return pencilSettings.color
            case .eraser:
                return .clear
            case .fill:
                return fillSettings.color
            case .eyedropper:
                return .black
            case .rectangle:
                return rectangleSettings.strokeColor
            case .circle:
                return circleSettings.strokeColor
            case .line:
                return lineSettings.strokeColor
            }
        }
        set {
            switch selectedTool {
            case .pencil:
                pencilSettings.color = newValue
            case .fill:
                fillSettings.color = newValue
            case .rectangle:
                rectangleSettings.strokeColor = newValue
            case .circle:
                circleSettings.strokeColor = newValue
            case .line:
                lineSettings.strokeColor = newValue
            default:
                break
            }
        }
    }

    /// 현재 선택된 도구의 브러시 크기 (UI 표시용)
    var currentBrushSize: Int {
        get {
            switch selectedTool {
            case .pencil:
                return pencilSettings.brushSize
            case .eraser:
                return eraserSettings.brushSize
            case .rectangle:
                return rectangleSettings.strokeWidth
            case .circle:
                return circleSettings.strokeWidth
            case .line:
                return lineSettings.strokeWidth
            default:
                return 1
            }
        }
        set {
            switch selectedTool {
            case .pencil:
                pencilSettings.brushSize = max(1, newValue)
            case .eraser:
                eraserSettings.brushSize = max(1, newValue)
            case .rectangle:
                rectangleSettings.strokeWidth = max(1, newValue)
            case .circle:
                circleSettings.strokeWidth = max(1, newValue)
            case .line:
                lineSettings.strokeWidth = max(1, newValue)
            default:
                break
            }
        }
    }

    /// 도구를 선택합니다
    /// - Parameter tool: 선택할 도구
    func selectTool(_ tool: DrawingTool) {
        selectedTool = tool
    }

    /// 특정 도구의 설정을 가져옵니다
    /// - Parameter tool: 도구 타입
    /// - Returns: 해당 도구의 설정
    func getSettings(for tool: DrawingTool) -> any ToolSettings {
        switch tool {
        case .pencil:
            return pencilSettings
        case .eraser:
            return eraserSettings
        case .fill:
            return fillSettings
        case .eyedropper:
            return eyedropperSettings
        case .rectangle:
            return rectangleSettings
        case .circle:
            return circleSettings
        case .line:
            return lineSettings
        }
    }

    /// 모든 설정을 기본값으로 초기화합니다
    func resetToDefaults() {
        pencilSettings = PencilSettings()
        eraserSettings = EraserSettings()
        rectangleSettings = ShapeSettings(toolType: .rectangle)
        circleSettings = ShapeSettings(toolType: .circle)
        lineSettings = ShapeSettings(toolType: .line)
        fillSettings = FillSettings()
        eyedropperSettings = EyedropperSettings()
    }
}
