//
//  ProjectDocument.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import Foundation

/// 프로젝트 메타데이터
struct ProjectMetadata: Codable {
    var version: String = "1.0"
    var createdAt: Date
    var modifiedAt: Date

    init() {
        let now = Date()
        self.createdAt = now
        self.modifiedAt = now
    }
}

/// 직렬화 가능한 타임라인 상태
struct SerializableTimelineState: Codable {
    var totalFrames: Int
    var currentFrameIndex: Int
    var fps: Int
    var playbackSpeed: Double
    var isLooping: Bool
    var onionSkinEnabled: Bool
    var onionSkinPrevFrames: Int
    var onionSkinNextFrames: Int
    var onionSkinOpacity: Double

    init(from settings: AnimationSettings, totalFrames: Int, currentFrameIndex: Int) {
        self.totalFrames = totalFrames
        self.currentFrameIndex = currentFrameIndex
        self.fps = settings.fps
        self.playbackSpeed = settings.playbackSpeed
        self.isLooping = settings.isLooping
        self.onionSkinEnabled = settings.onionSkinEnabled
        self.onionSkinPrevFrames = settings.onionSkinPrevFrames
        self.onionSkinNextFrames = settings.onionSkinNextFrames
        self.onionSkinOpacity = settings.onionSkinOpacity
    }

    func toAnimationSettings() -> AnimationSettings {
        var settings = AnimationSettings()
        settings.fps = fps
        settings.playbackSpeed = playbackSpeed
        settings.isLooping = isLooping
        settings.onionSkinEnabled = onionSkinEnabled
        settings.onionSkinPrevFrames = onionSkinPrevFrames
        settings.onionSkinNextFrames = onionSkinNextFrames
        settings.onionSkinOpacity = onionSkinOpacity
        return settings
    }
}

/// Pixapper 프로젝트 문서 (중앙 데이터 모델)
struct ProjectDocument: Codable {
    var metadata: ProjectMetadata
    var canvasWidth: Int
    var canvasHeight: Int
    var layers: [SerializableLayer]
    var selectedLayerIndex: Int
    var timeline: SerializableTimelineState
    var toolSettings: SerializableToolSettings
    var zoomLevel: Double

    /// 새 프로젝트 생성
    static func createNew(width: Int = 32, height: Int = 32) -> ProjectDocument {
        let layer = Layer(name: "Layer 1", width: width, height: height)
        let serializableLayer = SerializableLayer(from: layer)

        let animationSettings = AnimationSettings()
        let timelineState = SerializableTimelineState(
            from: animationSettings,
            totalFrames: 1,
            currentFrameIndex: 0
        )

        let toolSettingsManager = ToolSettingsManager()
        let toolSettings = SerializableToolSettings(from: toolSettingsManager)

        return ProjectDocument(
            metadata: ProjectMetadata(),
            canvasWidth: width,
            canvasHeight: height,
            layers: [serializableLayer],
            selectedLayerIndex: 0,
            timeline: timelineState,
            toolSettings: toolSettings,
            zoomLevel: 400.0
        )
    }

    /// 수정 시간 업데이트
    mutating func updateModifiedDate() {
        metadata.modifiedAt = Date()
    }
}
