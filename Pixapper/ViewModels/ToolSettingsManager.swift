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

    /// 공통 색상 관리자
    let colorManager: ColorManager

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

    /// 선택 도구 설정
    @Published var selectionSettings = SelectionSettings()

    /// 대칭 그리기 설정
    @Published var mirrorSettings = MirrorSettings()

    /// 디더링 설정
    @Published var ditheringSettings = DitheringSettings()

    /// 텍스트 설정
    @Published var textSettings = TextToolSettings()

    init(colorManager: ColorManager = ColorManager()) {
        self.colorManager = colorManager
    }

    /// 현재 도구에서 사용할 색상 (모든 도구가 공통 색상 사용)
    var currentColor: Color {
        get {
            // 지우개는 항상 clear
            if selectedTool == .eraser {
                return .clear
            }
            // 나머지 모든 도구는 공통 Primary 색상 사용
            return colorManager.primaryColor
        }
        set {
            // 지우개는 색상 설정 불가
            if selectedTool == .eraser {
                return
            }
            // Primary 색상 업데이트 (자동으로 최근 색상에 추가됨)
            colorManager.setPrimaryColor(newValue)
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
            case .mirror:
                return mirrorSettings.brushSize
            case .dithering:
                return ditheringSettings.brushSize
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
            case .mirror:
                mirrorSettings.brushSize = max(1, newValue)
            case .dithering:
                ditheringSettings.brushSize = max(1, newValue)
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
        case .rectangle:
            return rectangleSettings
        case .circle:
            return circleSettings
        case .line:
            return lineSettings
        case .selection:
            return selectionSettings
        case .mirror:
            return mirrorSettings
        case .dithering:
            return ditheringSettings
        case .text:
            return textSettings
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
        selectionSettings = SelectionSettings()
        mirrorSettings = MirrorSettings()
        ditheringSettings = DitheringSettings()
        textSettings = TextToolSettings()
    }
}
