//
//  SerializableToolSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 직렬화 가능한 도구 설정 모음
struct SerializableToolSettings: Codable {
    var selectedTool: String  // DrawingTool.rawValue
    var pencilColor: SerializableColor
    var pencilBrushSize: Int
    var eraserBrushSize: Int
    var fillColor: SerializableColor
    var rectangleStrokeColor: SerializableColor
    var rectangleStrokeWidth: Int
    var rectangleFillColor: SerializableColor?
    var circleStrokeColor: SerializableColor
    var circleStrokeWidth: Int
    var circleFillColor: SerializableColor?
    var lineStrokeColor: SerializableColor
    var lineStrokeWidth: Int

    init(from manager: ToolSettingsManager) {
        self.selectedTool = manager.selectedTool.rawValue
        self.pencilColor = SerializableColor(from: manager.pencilSettings.color)
        self.pencilBrushSize = manager.pencilSettings.brushSize
        self.eraserBrushSize = manager.eraserSettings.brushSize
        self.fillColor = SerializableColor(from: manager.fillSettings.color)
        self.rectangleStrokeColor = SerializableColor(from: manager.rectangleSettings.strokeColor)
        self.rectangleStrokeWidth = manager.rectangleSettings.strokeWidth
        self.rectangleFillColor = manager.rectangleSettings.fillColor.map { SerializableColor(from: $0) }
        self.circleStrokeColor = SerializableColor(from: manager.circleSettings.strokeColor)
        self.circleStrokeWidth = manager.circleSettings.strokeWidth
        self.circleFillColor = manager.circleSettings.fillColor.map { SerializableColor(from: $0) }
        self.lineStrokeColor = SerializableColor(from: manager.lineSettings.strokeColor)
        self.lineStrokeWidth = manager.lineSettings.strokeWidth
    }

    /// ToolSettingsManager에 적용
    func applyTo(manager: ToolSettingsManager) {
        if let tool = DrawingTool(rawValue: selectedTool) {
            manager.selectedTool = tool
        }
        manager.pencilSettings.color = pencilColor.toColor()
        manager.pencilSettings.brushSize = pencilBrushSize
        manager.eraserSettings.brushSize = eraserBrushSize
        manager.fillSettings.color = fillColor.toColor()
        manager.rectangleSettings.strokeColor = rectangleStrokeColor.toColor()
        manager.rectangleSettings.strokeWidth = rectangleStrokeWidth
        manager.rectangleSettings.fillColor = rectangleFillColor?.toColor()
        manager.circleSettings.strokeColor = circleStrokeColor.toColor()
        manager.circleSettings.strokeWidth = circleStrokeWidth
        manager.circleSettings.fillColor = circleFillColor?.toColor()
        manager.lineSettings.strokeColor = lineStrokeColor.toColor()
        manager.lineSettings.strokeWidth = lineStrokeWidth
    }
}
