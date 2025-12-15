//
//  SerializableToolSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 직렬화 가능한 도구 설정 모음
/// 색상은 ColorManager에서 별도로 관리됨
struct SerializableToolSettings: Codable {
    var selectedTool: String  // DrawingTool.rawValue
    var pencilBrushSize: Int
    var eraserBrushSize: Int
    var fillTolerance: Double
    var rectangleStrokeWidth: Int
    var rectangleIsFilled: Bool
    var circleStrokeWidth: Int
    var circleIsFilled: Bool
    var lineStrokeWidth: Int

    init(from manager: ToolSettingsManager) {
        self.selectedTool = manager.selectedTool.rawValue
        self.pencilBrushSize = manager.pencilSettings.brushSize
        self.eraserBrushSize = manager.eraserSettings.brushSize
        self.fillTolerance = manager.fillSettings.tolerance
        self.rectangleStrokeWidth = manager.rectangleSettings.strokeWidth
        self.rectangleIsFilled = manager.rectangleSettings.isFilled
        self.circleStrokeWidth = manager.circleSettings.strokeWidth
        self.circleIsFilled = manager.circleSettings.isFilled
        self.lineStrokeWidth = manager.lineSettings.strokeWidth
    }

    /// ToolSettingsManager에 적용
    func applyTo(manager: ToolSettingsManager) {
        if let tool = DrawingTool(rawValue: selectedTool) {
            manager.selectedTool = tool
        }
        manager.pencilSettings.brushSize = pencilBrushSize
        manager.eraserSettings.brushSize = eraserBrushSize
        manager.fillSettings.tolerance = fillTolerance
        manager.rectangleSettings.strokeWidth = rectangleStrokeWidth
        manager.rectangleSettings.isFilled = rectangleIsFilled
        manager.circleSettings.strokeWidth = circleStrokeWidth
        manager.circleSettings.isFilled = circleIsFilled
        manager.lineSettings.strokeWidth = lineStrokeWidth
    }
}
