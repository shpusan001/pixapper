//
//  CanvasCompositor.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// Canvas 렌더링을 위한 레이어 합성기
class CanvasCompositor {
    private var layers: [any CanvasCompositeLayer] = []

    /// 레이어 추가
    func addLayer(_ layer: any CanvasCompositeLayer) {
        layers.append(layer)
        sortLayers()
    }

    /// 레이어 제거
    func removeLayer(id: UUID) {
        layers.removeAll { $0.id == id }
    }

    /// 모든 레이어 제거
    func clearLayers() {
        layers.removeAll()
    }

    /// 특정 ID의 레이어 찾기
    func findLayer(id: UUID) -> (any CanvasCompositeLayer)? {
        return layers.first { $0.id == id }
    }

    /// zIndex 순서로 정렬
    private func sortLayers() {
        layers.sort { $0.zIndex < $1.zIndex }
    }

    /// 모든 레이어를 합성하여 최종 픽셀 배열 반환
    /// - Parameters:
    ///   - width: 캔버스 너비
    ///   - height: 캔버스 높이
    /// - Returns: 합성된 픽셀 배열
    func composite(width: Int, height: Int) -> [[Color?]] {
        guard !layers.isEmpty else {
            return Array(repeating: Array(repeating: nil, count: width), count: height)
        }

        // 빈 캔버스로 시작
        var result = Array(repeating: Array(repeating: nil as Color?, count: width), count: height)

        // zIndex 순서대로 레이어 합성
        for layer in layers {
            guard layer.isVisible else { continue }

            let layerPixels = layer.render()
            result = blend(bottom: result, top: layerPixels, opacity: layer.opacity, mode: layer.blendMode)
        }

        return result
    }

    /// 두 레이어를 블렌드
    private func blend(bottom: [[Color?]], top: [[Color?]], opacity: Double, mode: CompositeBlendMode) -> [[Color?]] {
        var result = bottom
        let height = min(bottom.count, top.count)
        let width = height > 0 ? min(bottom[0].count, top[0].count) : 0

        for y in 0..<height {
            for x in 0..<width {
                if let topColor = top[y][x] {
                    // 상위 레이어에 픽셀이 있으면 블렌드
                    let blended = blendColors(bottom: bottom[y][x], top: topColor, opacity: opacity, mode: mode)
                    result[y][x] = blended
                }
            }
        }

        return result
    }

    /// 두 색상을 블렌드
    private func blendColors(bottom: Color?, top: Color, opacity: Double, mode: CompositeBlendMode) -> Color {
        guard let bottomColor = bottom else {
            return top.opacity(opacity)
        }

        switch mode {
        case .normal:
            return normalBlend(bottom: bottomColor, top: top, opacity: opacity)
        case .multiply:
            return multiplyBlend(bottom: bottomColor, top: top, opacity: opacity)
        case .screen:
            return screenBlend(bottom: bottomColor, top: top, opacity: opacity)
        case .overlay:
            return overlayBlend(bottom: bottomColor, top: top, opacity: opacity)
        }
    }

    /// Normal blending (alpha composite)
    private func normalBlend(bottom: Color, top: Color, opacity: Double) -> Color {
        let nsBottom = NSColor(bottom)
        let nsTop = NSColor(top)

        guard let bottomRGB = nsBottom.usingColorSpace(.deviceRGB),
              let topRGB = nsTop.usingColorSpace(.deviceRGB) else {
            return top.opacity(opacity)
        }

        let alpha = topRGB.alphaComponent * opacity
        let r = topRGB.redComponent * alpha + bottomRGB.redComponent * (1 - alpha)
        let g = topRGB.greenComponent * alpha + bottomRGB.greenComponent * (1 - alpha)
        let b = topRGB.blueComponent * alpha + bottomRGB.blueComponent * (1 - alpha)

        return Color(red: r, green: g, blue: b)
    }

    /// Multiply blending
    private func multiplyBlend(bottom: Color, top: Color, opacity: Double) -> Color {
        let nsBottom = NSColor(bottom)
        let nsTop = NSColor(top)

        guard let bottomRGB = nsBottom.usingColorSpace(.deviceRGB),
              let topRGB = nsTop.usingColorSpace(.deviceRGB) else {
            return top.opacity(opacity)
        }

        let r = bottomRGB.redComponent * topRGB.redComponent
        let g = bottomRGB.greenComponent * topRGB.greenComponent
        let b = bottomRGB.blueComponent * topRGB.blueComponent

        return Color(red: r, green: g, blue: b).opacity(opacity)
    }

    /// Screen blending
    private func screenBlend(bottom: Color, top: Color, opacity: Double) -> Color {
        let nsBottom = NSColor(bottom)
        let nsTop = NSColor(top)

        guard let bottomRGB = nsBottom.usingColorSpace(.deviceRGB),
              let topRGB = nsTop.usingColorSpace(.deviceRGB) else {
            return top.opacity(opacity)
        }

        let r = 1 - (1 - bottomRGB.redComponent) * (1 - topRGB.redComponent)
        let g = 1 - (1 - bottomRGB.greenComponent) * (1 - topRGB.greenComponent)
        let b = 1 - (1 - bottomRGB.blueComponent) * (1 - topRGB.blueComponent)

        return Color(red: r, green: g, blue: b).opacity(opacity)
    }

    /// Overlay blending
    private func overlayBlend(bottom: Color, top: Color, opacity: Double) -> Color {
        let nsBottom = NSColor(bottom)
        let nsTop = NSColor(top)

        guard let bottomRGB = nsBottom.usingColorSpace(.deviceRGB),
              let topRGB = nsTop.usingColorSpace(.deviceRGB) else {
            return top.opacity(opacity)
        }

        func overlayChannel(_ base: Double, _ blend: Double) -> Double {
            if base < 0.5 {
                return 2 * base * blend
            } else {
                return 1 - 2 * (1 - base) * (1 - blend)
            }
        }

        let r = overlayChannel(bottomRGB.redComponent, topRGB.redComponent)
        let g = overlayChannel(bottomRGB.greenComponent, topRGB.greenComponent)
        let b = overlayChannel(bottomRGB.blueComponent, topRGB.blueComponent)

        return Color(red: r, green: g, blue: b).opacity(opacity)
    }
}
