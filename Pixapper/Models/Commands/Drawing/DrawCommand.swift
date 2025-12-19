//
//  DrawCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import SwiftUI

/// 픽셀 변경 정보를 담는 구조체
struct PixelChange {
    let x: Int
    let y: Int
    let value: PixelValue
}

/// 그리기 작업(연필, 지우개, 도형 등)을 캡슐화하는 Command
class DrawCommand: Command {
    /// TimelineViewModel에 대한 weak reference (Single Source of Truth)
    weak var timelineViewModel: TimelineViewModel?

    /// 변경할 레이어의 ID
    let layerId: UUID

    /// 변경 전 픽셀 상태
    private let oldPixels: [PixelChange]

    /// 변경 후 픽셀 상태
    private let newPixels: [PixelChange]

    /// 명령에 대한 설명
    var description: String {
        "Draw \(newPixels.count) pixels on layer \(layerId)"
    }

    /// DrawCommand 초기화
    /// - Parameters:
    ///   - timelineViewModel: Timeline을 관리하는 ViewModel
    ///   - layerId: 변경할 레이어의 ID
    ///   - oldPixels: 변경 전 픽셀들
    ///   - newPixels: 변경 후 픽셀들
    init(timelineViewModel: TimelineViewModel?, layerId: UUID, oldPixels: [PixelChange], newPixels: [PixelChange]) {
        self.timelineViewModel = timelineViewModel
        self.layerId = layerId
        self.oldPixels = oldPixels
        self.newPixels = newPixels
    }

    /// 명령을 실행합니다 (새 픽셀 적용)
    func execute() {
        timelineViewModel?.applyPixelChanges(layerId: layerId, changes: newPixels)
    }

    /// 명령을 취소합니다 (이전 픽셀 복원)
    func undo() {
        timelineViewModel?.applyPixelChanges(layerId: layerId, changes: oldPixels)
    }
}
