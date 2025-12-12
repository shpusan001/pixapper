//
//  RenderLayerFactory.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// Render Layer 생성을 위한 Factory
class RenderLayerFactory {

    /// Base render layer 생성 (Timeline Layer 래핑)
    static func createBaseLayer(layer: Layer, zIndex: Int) -> BaseRenderLayer {
        return BaseRenderLayer(layer: layer, zIndex: zIndex)
    }

    /// Floating selection layer 생성
    static func createFloatingSelectionLayer(
        pixels: [[Color?]],
        rect: CGRect,
        offset: CGPoint = .zero,
        canvasWidth: Int,
        canvasHeight: Int,
        opacity: Double = 1.0
    ) -> FloatingSelectionLayer {
        return FloatingSelectionLayer(
            pixels: pixels,
            rect: rect,
            offset: offset,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight,
            opacity: opacity
        )
    }

    /// Shape preview layer 생성
    static func createShapePreviewLayer(
        preview: [(x: Int, y: Int, color: Color)],
        canvasWidth: Int,
        canvasHeight: Int
    ) -> ShapePreviewLayer {
        return ShapePreviewLayer(
            preview: preview,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }

    /// Onion skin layer 생성
    static func createOnionSkinLayer(
        pixels: [[Color?]],
        tint: Color,
        opacity: Double
    ) -> OnionSkinRenderLayer {
        return OnionSkinRenderLayer(
            pixels: pixels,
            tint: tint,
            opacity: opacity
        )
    }

    /// Overlay layer 생성
    static func createOverlayLayer(
        type: OverlayLayer.OverlayType,
        canvasWidth: Int,
        canvasHeight: Int
    ) -> OverlayLayer {
        return OverlayLayer(
            type: type,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        )
    }
}
