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
    var timelineViewModel: TimelineViewModel? { get }
    var layerIndex: Int { get }
}

/// 공통 applyPixelChanges 구현 (PixelStateManager 사용)
extension LayerPixelApplicable {
    func applyPixelChanges(_ changes: [PixelChange]) {
        guard let layerVM = layerViewModel,
              let timelineVM = timelineViewModel,
              layerIndex < layerVM.layers.count else { return }

        let layerId = layerVM.layers[layerIndex].id

        // TimelineViewModel을 통해 픽셀 변경 적용 (Single Source of Truth)
        for change in changes {
            timelineVM.setPixel(layerId: layerId, x: change.x, y: change.y, color: change.color)
        }
    }
}
