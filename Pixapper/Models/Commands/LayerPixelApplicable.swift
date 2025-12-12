//
//  LayerPixelApplicable.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import Foundation

/// 레이어에 픽셀 변경사항을 적용하는 Command를 위한 프로토콜
protocol LayerPixelApplicable: Command {
    var layerViewModel: LayerViewModel? { get }
    var layerIndex: Int { get }
}

/// 공통 applyPixelChanges 구현
extension LayerPixelApplicable {
    func applyPixelChanges(_ changes: [PixelChange]) {
        guard let layerVM = layerViewModel,
              layerIndex < layerVM.layers.count else { return }

        for change in changes {
            layerVM.layers[layerIndex].setPixel(x: change.x, y: change.y, color: change.color)
        }
    }
}
