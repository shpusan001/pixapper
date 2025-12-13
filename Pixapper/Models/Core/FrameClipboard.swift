//
//  FrameClipboard.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 프레임 복사/붙여넣기를 위한 클립보드
/// - Note: 레이어 정보는 저장하지 않고, 키프레임 데이터만 저장합니다
///         붙여넣을 때 현재 선택된 레이어에 적용됩니다
struct FrameClipboard {
    /// 복사된 프레임 개수
    let frameCount: Int

    /// 상대 인덱스 -> 키프레임 픽셀 데이터
    /// - Example: 프레임 3-5를 복사하면 [0: pixels3, 2: pixels5]로 저장
    let keyframes: [Int: [[Color?]]]

    /// 원본 레이어 ID (참고용, 붙여넣기 시 사용하지 않음)
    let sourceLayerId: UUID?

    /// 클립보드가 비어있는지 확인
    var isEmpty: Bool {
        return frameCount == 0 && keyframes.isEmpty
    }

    init(frameCount: Int, keyframes: [Int: [[Color?]]], sourceLayerId: UUID? = nil) {
        self.frameCount = frameCount
        self.keyframes = keyframes
        self.sourceLayerId = sourceLayerId
    }

    /// 빈 클립보드 생성
    static var empty: FrameClipboard {
        return FrameClipboard(frameCount: 0, keyframes: [:], sourceLayerId: nil)
    }
}
