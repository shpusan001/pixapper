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
    let color: Color?
}

/// 그리기 작업(연필, 지우개, 도형 등)을 캡슐화하는 Command
class DrawCommand: LayerPixelApplicable {
    /// LayerViewModel에 대한 weak reference
    weak var layerViewModel: LayerViewModel?

    /// 변경할 레이어의 인덱스
    let layerIndex: Int

    /// 변경 전 픽셀 상태
    private let oldPixels: [PixelChange]

    /// 변경 후 픽셀 상태
    private let newPixels: [PixelChange]

    /// 명령에 대한 설명
    var description: String {
        "Draw \(newPixels.count) pixels on layer \(layerIndex)"
    }

    /// DrawCommand 초기화
    /// - Parameters:
    ///   - layerViewModel: 레이어를 관리하는 ViewModel
    ///   - layerIndex: 변경할 레이어의 인덱스
    ///   - oldPixels: 변경 전 픽셀들
    ///   - newPixels: 변경 후 픽셀들
    init(layerViewModel: LayerViewModel, layerIndex: Int, oldPixels: [PixelChange], newPixels: [PixelChange]) {
        self.layerViewModel = layerViewModel
        self.layerIndex = layerIndex
        self.oldPixels = oldPixels
        self.newPixels = newPixels
    }

    /// 명령을 실행합니다 (새 픽셀 적용)
    func execute() {
        applyPixelChanges(newPixels)
    }

    /// 명령을 취소합니다 (이전 픽셀 복원)
    func undo() {
        applyPixelChanges(oldPixels)
    }
}
