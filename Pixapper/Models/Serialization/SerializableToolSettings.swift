//
//  SerializableToolSettings.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 직렬화 가능한 도구 설정 모음
/// 색상은 ColorManager에서 별도로 관리됨
/// 표준 버전 관리 시스템 적용
struct SerializableToolSettings {
    var selectedTool: String  // DrawingTool.rawValue
    var pencilBrushSize: Int
    var eraserBrushSize: Int
    var fillTolerance: Double
    var rectangleStrokeWidth: Int
    var rectangleIsFilled: Bool
    var circleStrokeWidth: Int
    var circleIsFilled: Bool
    var lineStrokeWidth: Int

    // 버전 1.1에서 추가된 도구 설정들 (이제 non-optional)
    // Selection settings
    var selectionType: String

    // Mirror settings
    var mirrorBrushSize: Int
    var mirrorMode: String
    var mirrorAxisPosition: Double

    // Dithering settings
    var ditheringBrushSize: Int
    var ditheringPattern: String
    var ditheringDensity: Double
    var ditheringCustomPatternSize: Int
    var ditheringCustomPattern: [[Bool]]

    init(from manager: ToolSettingsManager) {
        // 기본 도구 설정 (v1.0)
        self.selectedTool = manager.selectedTool.rawValue
        self.pencilBrushSize = manager.pencilSettings.brushSize
        self.eraserBrushSize = manager.eraserSettings.brushSize
        self.fillTolerance = manager.fillSettings.tolerance
        self.rectangleStrokeWidth = manager.rectangleSettings.strokeWidth
        self.rectangleIsFilled = manager.rectangleSettings.isFilled
        self.circleStrokeWidth = manager.circleSettings.strokeWidth
        self.circleIsFilled = manager.circleSettings.isFilled
        self.lineStrokeWidth = manager.lineSettings.strokeWidth

        // 추가 도구 설정 (v1.1)
        self.selectionType = manager.selectionSettings.selectionType.rawValue
        self.mirrorBrushSize = manager.mirrorSettings.brushSize
        self.mirrorMode = manager.mirrorSettings.mode.rawValue
        self.mirrorAxisPosition = manager.mirrorSettings.axisPosition
        self.ditheringBrushSize = manager.ditheringSettings.brushSize
        self.ditheringPattern = manager.ditheringSettings.pattern.rawValue
        self.ditheringDensity = manager.ditheringSettings.density
        self.ditheringCustomPatternSize = manager.ditheringSettings.customPatternSize
        self.ditheringCustomPattern = manager.ditheringSettings.customPattern
    }

    /// ToolSettingsManager에 적용
    func applyTo(manager: ToolSettingsManager) {
        // 기본 도구 설정 (v1.0)
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

        // 추가 도구 설정 (v1.1, 이제 항상 존재)
        if let type = SelectionType(rawValue: selectionType) {
            manager.selectionSettings.selectionType = type
        }

        manager.mirrorSettings.brushSize = mirrorBrushSize
        if let mode = MirrorMode(rawValue: mirrorMode) {
            manager.mirrorSettings.mode = mode
        }
        manager.mirrorSettings.axisPosition = mirrorAxisPosition

        manager.ditheringSettings.brushSize = ditheringBrushSize
        if let pattern = DitheringPattern(rawValue: ditheringPattern) {
            manager.ditheringSettings.pattern = pattern
        }
        manager.ditheringSettings.density = ditheringDensity
        manager.ditheringSettings.customPatternSize = ditheringCustomPatternSize
        manager.ditheringSettings.customPattern = ditheringCustomPattern
    }
}

// MARK: - Codable (Custom Implementation)

extension SerializableToolSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case selectedTool
        case pencilBrushSize
        case eraserBrushSize
        case fillTolerance
        case rectangleStrokeWidth
        case rectangleIsFilled
        case circleStrokeWidth
        case circleIsFilled
        case lineStrokeWidth
        case selectionType
        case mirrorBrushSize
        case mirrorMode
        case mirrorAxisPosition
        case ditheringBrushSize
        case ditheringPattern
        case ditheringDensity
        case ditheringCustomPatternSize
        case ditheringCustomPattern
    }

    /// 표준 Encoding
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // v1.0 필드
        try container.encode(selectedTool, forKey: .selectedTool)
        try container.encode(pencilBrushSize, forKey: .pencilBrushSize)
        try container.encode(eraserBrushSize, forKey: .eraserBrushSize)
        try container.encode(fillTolerance, forKey: .fillTolerance)
        try container.encode(rectangleStrokeWidth, forKey: .rectangleStrokeWidth)
        try container.encode(rectangleIsFilled, forKey: .rectangleIsFilled)
        try container.encode(circleStrokeWidth, forKey: .circleStrokeWidth)
        try container.encode(circleIsFilled, forKey: .circleIsFilled)
        try container.encode(lineStrokeWidth, forKey: .lineStrokeWidth)

        // v1.1 필드
        try container.encode(selectionType, forKey: .selectionType)
        try container.encode(mirrorBrushSize, forKey: .mirrorBrushSize)
        try container.encode(mirrorMode, forKey: .mirrorMode)
        try container.encode(mirrorAxisPosition, forKey: .mirrorAxisPosition)
        try container.encode(ditheringBrushSize, forKey: .ditheringBrushSize)
        try container.encode(ditheringPattern, forKey: .ditheringPattern)
        try container.encode(ditheringDensity, forKey: .ditheringDensity)
        try container.encode(ditheringCustomPatternSize, forKey: .ditheringCustomPatternSize)
        try container.encode(ditheringCustomPattern, forKey: .ditheringCustomPattern)
    }

    /// 버전별 Custom Decoding
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // v1.0 필드 (항상 존재)
        self.selectedTool = try container.decode(String.self, forKey: .selectedTool)
        self.pencilBrushSize = try container.decode(Int.self, forKey: .pencilBrushSize)
        self.eraserBrushSize = try container.decode(Int.self, forKey: .eraserBrushSize)
        self.fillTolerance = try container.decode(Double.self, forKey: .fillTolerance)
        self.rectangleStrokeWidth = try container.decode(Int.self, forKey: .rectangleStrokeWidth)
        self.rectangleIsFilled = try container.decode(Bool.self, forKey: .rectangleIsFilled)
        self.circleStrokeWidth = try container.decode(Int.self, forKey: .circleStrokeWidth)
        self.circleIsFilled = try container.decode(Bool.self, forKey: .circleIsFilled)
        self.lineStrokeWidth = try container.decode(Int.self, forKey: .lineStrokeWidth)

        // v1.1 필드 (없으면 기본값)
        let defaultManager = ToolSettingsManager()

        self.selectionType = try container.decodeIfPresent(String.self, forKey: .selectionType)
            ?? defaultManager.selectionSettings.selectionType.rawValue

        self.mirrorBrushSize = try container.decodeIfPresent(Int.self, forKey: .mirrorBrushSize)
            ?? defaultManager.mirrorSettings.brushSize

        self.mirrorMode = try container.decodeIfPresent(String.self, forKey: .mirrorMode)
            ?? defaultManager.mirrorSettings.mode.rawValue

        self.mirrorAxisPosition = try container.decodeIfPresent(Double.self, forKey: .mirrorAxisPosition)
            ?? defaultManager.mirrorSettings.axisPosition

        self.ditheringBrushSize = try container.decodeIfPresent(Int.self, forKey: .ditheringBrushSize)
            ?? defaultManager.ditheringSettings.brushSize

        self.ditheringPattern = try container.decodeIfPresent(String.self, forKey: .ditheringPattern)
            ?? defaultManager.ditheringSettings.pattern.rawValue

        self.ditheringDensity = try container.decodeIfPresent(Double.self, forKey: .ditheringDensity)
            ?? defaultManager.ditheringSettings.density

        self.ditheringCustomPatternSize = try container.decodeIfPresent(Int.self, forKey: .ditheringCustomPatternSize)
            ?? defaultManager.ditheringSettings.customPatternSize

        self.ditheringCustomPattern = try container.decodeIfPresent([[Bool]].self, forKey: .ditheringCustomPattern)
            ?? defaultManager.ditheringSettings.customPattern
    }
}
