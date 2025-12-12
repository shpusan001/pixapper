//
//  RenderLayerManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// Render Layer 관리 및 Compositor 업데이트를 담당하는 매니저
class RenderLayerManager {
    private let compositor: CanvasCompositor

    init() {
        self.compositor = CanvasCompositor()
    }

    /// Timeline layers를 기반으로 compositor 업데이트
    /// - Parameters:
    ///   - layers: Timeline layers
    ///   - shapePreview: 도형 미리보기 (있으면)
    ///   - selectionState: 선택 상태 (있으면)
    ///   - canvasWidth: 캔버스 너비
    ///   - canvasHeight: 캔버스 높이
    func updateCompositor(
        layers: [Layer],
        shapePreview: [(x: Int, y: Int, color: Color)],
        selectionState: SelectionState?,
        canvasWidth: Int,
        canvasHeight: Int
    ) {
        compositor.clearLayers()

        // 1. Base layers (Timeline layers)
        for (index, layer) in layers.enumerated().reversed() {
            let baseLayer = RenderLayerFactory.createBaseLayer(layer: layer, zIndex: index)
            compositor.addLayer(baseLayer)
        }

        // 2. Shape preview layer
        if !shapePreview.isEmpty {
            let shapeLayer = RenderLayerFactory.createShapePreviewLayer(
                preview: shapePreview,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight
            )
            compositor.addLayer(shapeLayer)
        }

        // 3. Floating selection layer (최상위)
        if let state = selectionState,
           state.isFloating {
            let floatingLayer = RenderLayerFactory.createFloatingSelectionLayer(
                pixels: state.pixels,
                rect: state.rect,
                offset: state.offset,
                canvasWidth: canvasWidth,
                canvasHeight: canvasHeight,
                opacity: state.opacity
            )
            compositor.addLayer(floatingLayer)
        }
    }

    /// 합성된 픽셀 배열 반환
    func getCompositePixels(width: Int, height: Int) -> [[Color?]] {
        return compositor.composite(width: width, height: height)
    }
}

// MARK: - SelectionState

/// 선택 상태를 캡슐화
struct SelectionState {
    let pixels: [[Color?]]
    let rect: CGRect
    let offset: CGPoint
    let isFloating: Bool
    let opacity: Double
}
