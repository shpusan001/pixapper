//
//  Frame.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

/// 레이어의 타임라인 - 키프레임만 저장하는 효율적인 구조
struct LayerTimeline {
    private var keyframes: [Int: [[Color?]]] = [:]  // frameIndex -> pixels

    /// 특정 프레임에 키프레임 설정
    mutating func setKeyframe(at frameIndex: Int, pixels: [[Color?]]) {
        keyframes[frameIndex] = pixels
    }

    /// 특정 프레임의 키프레임 제거
    mutating func removeKeyframe(at frameIndex: Int) {
        keyframes.removeValue(forKey: frameIndex)
    }

    /// 특정 프레임이 키프레임인지 확인
    func isKeyframe(at frameIndex: Int) -> Bool {
        return keyframes[frameIndex] != nil
    }

    /// 특정 프레임의 유효한 픽셀 데이터 반환 (키프레임 또는 이전 키프레임)
    func getEffectivePixels(at frameIndex: Int) -> [[Color?]]? {
        // 현재 프레임이 키프레임이면 반환
        if let pixels = keyframes[frameIndex] {
            return pixels
        }

        // 이전 키프레임 찾기
        let previousKeyframes = keyframes.keys.filter { $0 < frameIndex }.sorted()
        if let lastKeyframe = previousKeyframes.last {
            return keyframes[lastKeyframe]
        }

        return nil
    }

    /// 특정 프레임이 속한 키프레임 인덱스 찾기
    func getOwningKeyframe(at frameIndex: Int) -> Int? {
        if keyframes[frameIndex] != nil {
            return frameIndex
        }

        let previousKeyframes = keyframes.keys.filter { $0 < frameIndex }.sorted()
        return previousKeyframes.last
    }

    /// 키프레임 span 계산 (시작, 길이)
    func getKeyframeSpan(at frameIndex: Int, totalFrames: Int) -> (start: Int, length: Int)? {
        guard let keyframeStart = getOwningKeyframe(at: frameIndex) else {
            return nil
        }

        // 다음 키프레임 찾기
        let nextKeyframes = keyframes.keys.filter { $0 > keyframeStart }.sorted()
        let spanEnd = nextKeyframes.first.map { $0 - 1 } ?? (totalFrames - 1)

        let length = spanEnd - keyframeStart + 1
        return (start: keyframeStart, length: length)
    }

    /// 모든 키프레임 인덱스 반환
    func getAllKeyframeIndices() -> [Int] {
        return keyframes.keys.sorted()
    }

    /// 키프레임 개수
    var keyframeCount: Int {
        return keyframes.count
    }

    /// 이 레이어의 최대 프레임 인덱스 (마지막 키프레임 인덱스, 없으면 0)
    var maxFrameIndex: Int {
        return keyframes.keys.max() ?? 0
    }

    /// 특정 인덱스 이후의 모든 키프레임을 offset만큼 이동
    /// - Parameters:
    ///   - index: 기준 인덱스 (이 인덱스보다 큰 키프레임들이 이동됨)
    ///   - offset: 이동할 오프셋 (삭제 시 -1, 삽입 시 +1)
    mutating func shiftKeyframes(after index: Int, by offset: Int) {
        guard offset != 0 else { return }

        var newKeyframes: [Int: [[Color?]]] = [:]

        for (frameIndex, pixels) in keyframes {
            if frameIndex > index {
                // index 이후의 키프레임은 offset만큼 이동
                let newIndex = frameIndex + offset
                if newIndex >= 0 {
                    newKeyframes[newIndex] = pixels
                }
            } else {
                // index 이하의 키프레임은 그대로 유지
                newKeyframes[frameIndex] = pixels
            }
        }

        keyframes = newKeyframes
    }
}

/// 각 레이어의 셀 데이터 (픽셀만 포함) - 호환성을 위해 유지
struct CellData: Identifiable {
    let id = UUID()
    let layerId: UUID
    var pixels: [[Color?]]
    var isKeyframe: Bool

    init(width: Int, height: Int, layerId: UUID, isKeyframe: Bool = true) {
        self.layerId = layerId
        self.pixels = Array(repeating: Array(repeating: nil, count: width), count: height)
        self.isKeyframe = isKeyframe
    }

    init(pixels: [[Color?]], layerId: UUID, isKeyframe: Bool = true) {
        self.layerId = layerId
        self.pixels = pixels
        self.isKeyframe = isKeyframe
    }

    func getPixel(x: Int, y: Int) -> Color? {
        guard y >= 0 && y < pixels.count && x >= 0 && x < pixels[0].count else {
            return nil
        }
        return pixels[y][x]
    }

    mutating func setPixel(x: Int, y: Int, color: Color?) {
        guard y >= 0 && y < pixels.count && x >= 0 && x < pixels[0].count else {
            return
        }
        pixels[y][x] = color
    }
}

/// 프레임 = 모든 레이어의 셀 데이터 묶음
struct Frame: Identifiable {
    let id = UUID()
    var cells: [CellData]  // 레이어별 픽셀 데이터 (레이어 개수만큼)

    init(layers: [Layer], width: Int, height: Int) {
        self.cells = layers.map { layer in
            CellData(width: width, height: height, layerId: layer.id)
        }
    }

    init(cells: [CellData]) {
        self.cells = cells
    }

    // 특정 레이어의 셀 찾기
    func cell(for layerId: UUID) -> CellData? {
        cells.first { $0.layerId == layerId }
    }

    // 특정 레이어의 셀 인덱스 찾기
    func cellIndex(for layerId: UUID) -> Int? {
        cells.firstIndex { $0.layerId == layerId }
    }

    // 특정 레이어의 셀이 키프레임인지 확인
    func isKeyframe(for layerId: UUID) -> Bool {
        cell(for: layerId)?.isKeyframe ?? false
    }

    // 키프레임으로 변환
    mutating func convertToKeyframe(for layerId: UUID) {
        if let index = cellIndex(for: layerId) {
            cells[index].isKeyframe = true
        }
    }

    // 일반 프레임으로 변환
    mutating func removeKeyframe(for layerId: UUID) {
        if let index = cellIndex(for: layerId) {
            cells[index].isKeyframe = false
        }
    }
}

struct AnimationSettings {
    var fps: Int = 12
    var playbackSpeed: Double = 1.0
    var isLooping: Bool = true
    var onionSkinEnabled: Bool = false
    var onionSkinPrevFrames: Int = 1
    var onionSkinNextFrames: Int = 1
    var onionSkinOpacity: Double = 0.3

    var effectiveFPS: Double {
        Double(fps) * playbackSpeed
    }

    var frameDuration: Double {
        1.0 / effectiveFPS
    }
}
