//
//  SerializableLayer.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import Foundation

/// 직렬화 가능한 레이어 타임라인
struct SerializableLayerTimeline: Codable {
    /// 키프레임 데이터: [프레임 인덱스: 픽셀 데이터]
    var keyframes: [Int: [[SerializableColor?]]]
    /// Extended frame span의 끝 인덱스 (버전 1.1에서 추가, 하위 호환성을 위해 optional)
    var spanEndIndex: Int?

    init(from timeline: LayerTimeline) {
        var serializedKeyframes: [Int: [[SerializableColor?]]] = [:]

        for frameIndex in timeline.getAllKeyframeIndices() {
            if let pixels = timeline.getKeyframe(at: frameIndex) {
                serializedKeyframes[frameIndex] = pixels.toSerializable()
            }
        }

        self.keyframes = serializedKeyframes
        self.spanEndIndex = timeline.maxFrameIndex
    }

    /// LayerTimeline로 변환
    func toLayerTimeline() -> LayerTimeline {
        var timeline = LayerTimeline()

        for (frameIndex, serializedPixels) in keyframes {
            let pixels = serializedPixels.toColors()
            timeline.setKeyframe(at: frameIndex, pixels: pixels)
        }

        // Span 끝 인덱스 복원 (없으면 자동 계산됨)
        if let spanEnd = spanEndIndex {
            timeline.setSpanEnd(at: spanEnd)
        }

        return timeline
    }
}

/// 직렬화 가능한 레이어
struct SerializableLayer: Codable, Identifiable {
    let id: String  // UUID.uuidString
    var name: String
    var isVisible: Bool
    var opacity: Double
    var timeline: SerializableLayerTimeline

    init(from layer: Layer) {
        self.id = layer.id.uuidString
        self.name = layer.name
        self.isVisible = layer.isVisible
        self.opacity = layer.opacity
        self.timeline = SerializableLayerTimeline(from: layer.timeline)
    }

    /// Layer로 변환 (현재 픽셀은 첫 번째 키프레임 또는 빈 배열)
    func toLayer(width: Int, height: Int) -> Layer {
        let layerTimeline = timeline.toLayerTimeline()

        // 현재 작업 픽셀은 프레임 0의 픽셀로 초기화 (없으면 빈 픽셀)
        let currentPixels = layerTimeline.getEffectivePixels(at: 0)
            ?? Layer.createEmptyPixels(width: width, height: height)

        // UUID 복원 (저장된 ID 사용, 실패 시 새로운 UUID 생성)
        let restoredId = UUID(uuidString: id) ?? UUID()
        var layer = Layer(id: restoredId, name: name, pixels: currentPixels, timeline: layerTimeline)

        layer.isVisible = isVisible
        layer.opacity = opacity

        return layer
    }
}
