//
//  Layer.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct Layer: Identifiable {
    let id = UUID()
    var name: String
    var pixels: [[Color?]]  // 현재 작업 중인 픽셀 (캐시)
    var isVisible: Bool = true
    var opacity: Double = 1.0
    var timeline: LayerTimeline  // 실제 키프레임 데이터 저장소

    /// 빈 픽셀 배열 생성 헬퍼 메서드
    static func createEmptyPixels(width: Int, height: Int) -> [[Color?]] {
        return Array(repeating: Array(repeating: nil as Color?, count: width), count: height)
    }

    init(name: String, width: Int, height: Int) {
        self.name = name
        self.pixels = Layer.createEmptyPixels(width: width, height: height)
        self.timeline = LayerTimeline()

        // 첫 프레임을 빈 키프레임으로 초기화
        self.timeline.setKeyframe(at: 0, pixels: self.pixels)
    }

    init(name: String, pixels: [[Color?]]) {
        self.name = name
        self.pixels = pixels
        self.timeline = LayerTimeline()

        // 첫 프레임을 현재 픽셀로 초기화
        self.timeline.setKeyframe(at: 0, pixels: pixels)
    }

    // Timeline을 포함한 완전 초기화
    init(name: String, pixels: [[Color?]], timeline: LayerTimeline) {
        self.name = name
        self.pixels = pixels
        self.timeline = timeline
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

    /// 새로운 UUID로 레이어 복제
    /// - Note: Layer는 struct이므로 pixels와 timeline이 자동으로 deep copy됨
    ///   - pixels: [[Color?]] (Array와 Color는 모두 value type)
    ///   - timeline: LayerTimeline (struct, keyframes Dictionary도 복사됨)
    /// - Parameter newName: 복제된 레이어의 이름
    /// - Returns: 새로운 UUID와 복사된 데이터를 가진 Layer
    func duplicate(newName: String) -> Layer {
        return Layer(name: newName, pixels: self.pixels, timeline: self.timeline)
    }

    /// 캔버스 크기를 변경합니다 (기존 픽셀 데이터는 왼쪽 위부터 유지)
    mutating func resizeCanvas(width: Int, height: Int) {
        let oldHeight = pixels.count
        let oldWidth = pixels.isEmpty ? 0 : pixels[0].count

        var newPixels = Layer.createEmptyPixels(width: width, height: height)

        // 기존 픽셀 복사 (범위 내에서만)
        for y in 0..<min(oldHeight, height) {
            for x in 0..<min(oldWidth, width) {
                newPixels[y][x] = pixels[y][x]
            }
        }

        pixels = newPixels
    }
}
