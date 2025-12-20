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
    /// 변경할 레이어의 ID
    let layerId: UUID

    /// 명령이 실행된 프레임 인덱스
    private let frameIndex: Int

    /// 변경 전 픽셀 상태
    private let oldPixels: [PixelChange]

    /// 변경 후 픽셀 상태
    private let newPixels: [PixelChange]

    /// 픽셀 변경 적용 클로저 (순환 참조 방지를 위해 weak capture)
    private let applyChanges: (UUID, Int, [PixelChange]) -> Void

    /// 명령에 대한 설명
    var description: String {
        "Draw \(newPixels.count) pixels on layer \(layerId) at frame \(frameIndex)"
    }

    /// DrawCommand 초기화
    /// - Parameters:
    ///   - timelineViewModel: Timeline을 관리하는 ViewModel
    ///   - layerId: 변경할 레이어의 ID
    ///   - frameIndex: 명령이 실행되는 프레임 인덱스
    ///   - oldPixels: 변경 전 픽셀들
    ///   - newPixels: 변경 후 픽셀들
    init(timelineViewModel: TimelineViewModel?, layerId: UUID, frameIndex: Int, oldPixels: [PixelChange], newPixels: [PixelChange]) {
        self.layerId = layerId
        self.frameIndex = frameIndex
        self.oldPixels = oldPixels
        self.newPixels = newPixels

        // 클로저로 메서드 캡처 (weak capture로 순환 참조 방지)
        // 프레임 전환 후 픽셀 변경 적용
        self.applyChanges = { [weak timelineViewModel] layerId, targetFrame, changes in
            guard let timeline = timelineViewModel else { return }

            // 현재 프레임이 명령 프레임과 다르면 자동 전환
            if timeline.currentFrameIndex != targetFrame {
                timeline.selectFrame(at: targetFrame, clearSelection: true)
            }

            // 픽셀 변경 적용
            timeline.applyPixelChanges(layerId: layerId, changes: changes)
        }
    }

    /// 명령을 실행합니다 (새 픽셀 적용)
    func execute() {
        applyChanges(layerId, frameIndex, newPixels)
    }

    /// 명령을 취소합니다 (이전 픽셀 복원)
    func undo() {
        applyChanges(layerId, frameIndex, oldPixels)
    }
}
