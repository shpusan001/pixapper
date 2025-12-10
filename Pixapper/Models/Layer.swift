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

    init(name: String, width: Int, height: Int) {
        self.name = name
        self.pixels = Array(repeating: Array(repeating: nil, count: width), count: height)
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
}
