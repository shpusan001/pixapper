//
//  ProjectDocument.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//  Updated with standard version management on 2025-12-16.
//

import Foundation

/// 프로젝트 메타데이터
struct ProjectMetadata: Codable {
    var version: SemanticVersion
    var createdAt: Date
    var modifiedAt: Date

    init(version: SemanticVersion = .current) {
        let now = Date()
        self.version = version
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
/// 표준 버전 관리 시스템 적용
struct ProjectDocument {
    var metadata: ProjectMetadata
    var canvasWidth: Int
    var canvasHeight: Int
    var layers: [SerializableLayer]
    var selectedLayerIndex: Int
    var timeline: SerializableTimelineState
    var toolSettings: SerializableToolSettings
    var zoomLevel: Double
    var colorPalette: [SerializableColor]

    // 버전 1.1에서 추가된 필드들 (이제 non-optional, 기본값 제공)
    var primaryColor: SerializableColor
    var secondaryColor: SerializableColor
    var canvasBackgroundMode: String
    var showGrid: Bool

    // MARK: - Initialization

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

        // 기본 팔레트 (ColorManager의 초기값)
        let colorManager = ColorManager()
        let defaultPalette = colorManager.palette.map { SerializableColor(from: $0) }
        let defaultPrimary = SerializableColor(from: colorManager.primaryColor)
        let defaultSecondary = SerializableColor(from: colorManager.secondaryColor)

        return ProjectDocument(
            metadata: ProjectMetadata(),
            canvasWidth: width,
            canvasHeight: height,
            layers: [serializableLayer],
            selectedLayerIndex: 0,
            timeline: timelineState,
            toolSettings: toolSettings,
            zoomLevel: 400.0,
            colorPalette: defaultPalette,
            primaryColor: defaultPrimary,
            secondaryColor: defaultSecondary,
            canvasBackgroundMode: CanvasBackgroundMode.checkerboard.rawValue,
            showGrid: true
        )
    }

    /// 수정 시간 업데이트
    mutating func updateModifiedDate() {
        metadata.modifiedAt = Date()
    }

    // MARK: - Validation

    /// 데이터 유효성 검증
    func validate() throws {
        // 캔버스 크기 검증
        guard canvasWidth > 0 && canvasWidth <= 1024 else {
            throw ProjectDocumentError.validationFailed("Canvas width must be between 1 and 1024, got \(canvasWidth)")
        }
        guard canvasHeight > 0 && canvasHeight <= 1024 else {
            throw ProjectDocumentError.validationFailed("Canvas height must be between 1 and 1024, got \(canvasHeight)")
        }

        // 레이어 검증
        guard !layers.isEmpty else {
            throw ProjectDocumentError.validationFailed("Project must have at least one layer")
        }
        guard selectedLayerIndex >= 0 && selectedLayerIndex < layers.count else {
            throw ProjectDocumentError.validationFailed("Selected layer index \(selectedLayerIndex) is out of bounds (0..<\(layers.count))")
        }

        // 타임라인 검증
        guard timeline.totalFrames > 0 else {
            throw ProjectDocumentError.validationFailed("Total frames must be greater than 0")
        }
        guard timeline.currentFrameIndex >= 0 && timeline.currentFrameIndex < timeline.totalFrames else {
            throw ProjectDocumentError.validationFailed("Current frame index \(timeline.currentFrameIndex) is out of bounds (0..<\(timeline.totalFrames))")
        }

        // 줌 레벨 검증
        guard zoomLevel >= 100 && zoomLevel <= 1600 else {
            throw ProjectDocumentError.validationFailed("Zoom level must be between 100 and 1600, got \(zoomLevel)")
        }
    }
}

// MARK: - Codable (Custom Implementation)

extension ProjectDocument: Codable {
    enum CodingKeys: String, CodingKey {
        case metadata
        case canvasWidth
        case canvasHeight
        case layers
        case selectedLayerIndex
        case timeline
        case toolSettings
        case zoomLevel
        case colorPalette
        case primaryColor
        case secondaryColor
        case canvasBackgroundMode
        case showGrid
    }

    /// 표준 Encoding (현재 버전 형식으로 저장)
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(metadata, forKey: .metadata)
        try container.encode(canvasWidth, forKey: .canvasWidth)
        try container.encode(canvasHeight, forKey: .canvasHeight)
        try container.encode(layers, forKey: .layers)
        try container.encode(selectedLayerIndex, forKey: .selectedLayerIndex)
        try container.encode(timeline, forKey: .timeline)
        try container.encode(toolSettings, forKey: .toolSettings)
        try container.encode(zoomLevel, forKey: .zoomLevel)
        try container.encode(colorPalette, forKey: .colorPalette)
        try container.encode(primaryColor, forKey: .primaryColor)
        try container.encode(secondaryColor, forKey: .secondaryColor)
        try container.encode(canvasBackgroundMode, forKey: .canvasBackgroundMode)
        try container.encode(showGrid, forKey: .showGrid)
    }

    /// 버전별 Custom Decoding (표준 패턴)
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // 1. 버전 먼저 읽기
        let metadata = try container.decode(ProjectMetadata.self, forKey: .metadata)
        let version = metadata.version

        // 2. 버전 호환성 체크
        guard SemanticVersion.current.canRead(version) else {
            throw ProjectDocumentError.incompatibleVersion(file: version, app: .current)
        }

        // 3. 공통 필드 (모든 버전에 존재)
        self.metadata = metadata
        self.canvasWidth = try container.decode(Int.self, forKey: .canvasWidth)
        self.canvasHeight = try container.decode(Int.self, forKey: .canvasHeight)
        self.layers = try container.decode([SerializableLayer].self, forKey: .layers)
        self.selectedLayerIndex = try container.decode(Int.self, forKey: .selectedLayerIndex)
        self.timeline = try container.decode(SerializableTimelineState.self, forKey: .timeline)
        self.toolSettings = try container.decode(SerializableToolSettings.self, forKey: .toolSettings)
        self.zoomLevel = try container.decode(Double.self, forKey: .zoomLevel)
        self.colorPalette = try container.decode([SerializableColor].self, forKey: .colorPalette)

        // 4. 버전별 필드 디코딩
        if version >= .v1_1 {
            // v1.1+ 필드들
            self.primaryColor = try container.decode(SerializableColor.self, forKey: .primaryColor)
            self.secondaryColor = try container.decode(SerializableColor.self, forKey: .secondaryColor)
            self.canvasBackgroundMode = try container.decode(String.self, forKey: .canvasBackgroundMode)
            self.showGrid = try container.decode(Bool.self, forKey: .showGrid)
        } else {
            // v1.0 → 기본값 사용
            let colorManager = ColorManager()
            self.primaryColor = SerializableColor(from: colorManager.primaryColor)
            self.secondaryColor = SerializableColor(from: colorManager.secondaryColor)
            self.canvasBackgroundMode = CanvasBackgroundMode.checkerboard.rawValue
            self.showGrid = true
        }

        // 5. 데이터 검증
        try validate()
    }
}
