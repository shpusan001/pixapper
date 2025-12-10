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
class DrawCommand: Command {
    /// LayerViewModel에 대한 weak reference
    private weak var layerViewModel: LayerViewModel?

    /// 변경할 레이어의 인덱스
    private let layerIndex: Int

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
        applyPixels(newPixels)
    }

    /// 명령을 취소합니다 (이전 픽셀 복원)
    func undo() {
        applyPixels(oldPixels)
    }

    /// 픽셀 변경을 실제로 적용합니다
    /// - Parameter pixels: 적용할 픽셀들
    private func applyPixels(_ pixels: [PixelChange]) {
        guard let layerViewModel = layerViewModel,
              layerIndex < layerViewModel.layers.count else {
            return
        }

        for pixel in pixels {
            layerViewModel.layers[layerIndex].setPixel(x: pixel.x, y: pixel.y, color: pixel.color)
        }
    }
}
