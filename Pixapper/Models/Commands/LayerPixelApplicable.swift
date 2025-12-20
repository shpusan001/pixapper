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
    var frameIndex: Int { get }
}

/// 공통 applyPixelChanges 구현 (PixelStateManager 사용)
extension LayerPixelApplicable {
    func applyPixelChanges(_ changes: [PixelChange]) {
        guard let layerVM = layerViewModel,
              let timelineVM = timelineViewModel,
              layerIndex < layerVM.layers.count else { return }

        // 현재 프레임이 명령 프레임과 다르면 자동 전환
        if timelineVM.currentFrameIndex != frameIndex {
            timelineVM.selectFrame(at: frameIndex, clearSelection: true)
        }

        let layerId = layerVM.layers[layerIndex].id

        // 대량 픽셀 변경 API 사용 (한 번에 처리 → syncToTimeline 1회만 호출)
        // setPixel을 하나씩 호출하면 syncToTimeline이 매번 호출되어 성능 저하 및 상태 불일치 발생
        timelineVM.applyPixelChanges(layerId: layerId, changes: changes)
    }
}
