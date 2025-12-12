//
//  CanvasCompositeLayer.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// Canvas 렌더링을 위한 합성 레이어 프로토콜
/// Timeline의 Layer와는 별개로, 렌더링 시 사용되는 임시 레이어
protocol CanvasCompositeLayer: Identifiable {
    var id: UUID { get }
    var zIndex: Int { get }
    var opacity: Double { get }
    var isVisible: Bool { get }
    var blendMode: CompositeBlendMode { get }

    /// 레이어의 픽셀 데이터를 반환
    /// - Returns: 2D 픽셀 배열 (nil은 투명)
    func render() -> [[Color?]]
}

/// Composite Layer의 블렌드 모드
enum CompositeBlendMode {
    case normal      // 기본 (알파 블렌딩)
    case multiply    // 곱하기
    case screen      // 스크린
    case overlay     // 오버레이
    // 필요시 추가 가능
}

/// Composite Layer 타입 구분
enum CompositeLayerType {
    case base               // Timeline Layer 기반
    case floatingSelection  // 부유 선택 영역
    case shapePreview       // 도형 미리보기
    case onionSkin          // 어니언 스킨
    case overlay            // Grid, Guides 등
}

/// 기본 구현: 대부분의 레이어에 적용되는 기본값
extension CanvasCompositeLayer {
    var opacity: Double { 1.0 }
    var isVisible: Bool { true }
    var blendMode: CompositeBlendMode { .normal }
}

// MARK: - BaseCompositeLayer

/// Timeline Layer를 래핑하는 기본 합성 레이어
class BaseCompositeLayer: CanvasCompositeLayer {
    let id: UUID
    let zIndex: Int
    var opacity: Double
    var isVisible: Bool
    let blendMode: CompositeBlendMode = .normal

    private let layer: Layer

    init(layer: Layer, zIndex: Int) {
        self.id = layer.id
        self.zIndex = zIndex
        self.opacity = layer.opacity
        self.isVisible = layer.isVisible
        self.layer = layer
    }

    func render() -> [[Color?]] {
        return layer.pixels
    }
}

// MARK: - FloatingSelectionLayer

/// 부유 선택 영역 레이어 (이동/변형 중인 선택 영역)
class FloatingSelectionLayer: CanvasCompositeLayer {
    let id = UUID()
    let zIndex: Int = 1000  // 항상 최상위
    var opacity: Double
    var isVisible: Bool = true
    let blendMode: CompositeBlendMode = .normal

    private let pixels: [[Color?]]
    private let rect: CGRect
    private let offset: CGPoint
    private let canvasWidth: Int
    private let canvasHeight: Int

    /// - Parameters:
    ///   - pixels: 선택된 픽셀 데이터
    ///   - rect: 선택 영역의 위치와 크기
    ///   - offset: 이동 오프셋 (드래그 중일 때)
    ///   - canvasWidth: 캔버스 너비
    ///   - canvasHeight: 캔버스 높이
    ///   - opacity: 투명도 (기본 1.0, 이동 중엔 0.6)
    init(pixels: [[Color?]], rect: CGRect, offset: CGPoint = .zero, canvasWidth: Int, canvasHeight: Int, opacity: Double = 1.0) {
        self.pixels = pixels
        self.rect = rect
        self.offset = offset
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.opacity = opacity
    }

    func render() -> [[Color?]] {
        // 캔버스 크기의 빈 픽셀 배열 생성
        var result = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)

        // 실제 위치 계산 (rect + offset)
        let effectiveX = Int(rect.minX + offset.x)
        let effectiveY = Int(rect.minY + offset.y)

        // 선택된 픽셀을 해당 위치에 배치
        for y in 0..<pixels.count {
            for x in 0..<pixels[y].count {
                if let color = pixels[y][x] {
                    let targetX = effectiveX + x
                    let targetY = effectiveY + y
                    if targetX >= 0 && targetX < canvasWidth && targetY >= 0 && targetY < canvasHeight {
                        result[targetY][targetX] = color
                    }
                }
            }
        }

        return result
    }
}

// MARK: - ShapePreviewLayer

/// 도형 미리보기 레이어 (도형 그리기 중인 상태)
class ShapePreviewLayer: CanvasCompositeLayer {
    let id = UUID()
    let zIndex: Int = 999  // Floating selection 바로 아래
    var opacity: Double = 0.5  // 반투명
    var isVisible: Bool = true
    let blendMode: CompositeBlendMode = .normal

    private let preview: [(x: Int, y: Int, color: Color)]
    private let canvasWidth: Int
    private let canvasHeight: Int

    init(preview: [(x: Int, y: Int, color: Color)], canvasWidth: Int, canvasHeight: Int) {
        self.preview = preview
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }

    func render() -> [[Color?]] {
        var result = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)

        for pixel in preview {
            if pixel.x >= 0 && pixel.x < canvasWidth && pixel.y >= 0 && pixel.y < canvasHeight {
                result[pixel.y][pixel.x] = pixel.color
            }
        }

        return result
    }
}

// MARK: - OnionSkinCompositeLayer

/// 어니언 스킨 레이어 (이전/이후 프레임 표시)
class OnionSkinCompositeLayer: CanvasCompositeLayer {
    let id = UUID()
    let zIndex: Int = -100  // Base layers 아래
    var opacity: Double
    var isVisible: Bool = true
    let blendMode: CompositeBlendMode = .normal

    private let pixels: [[Color?]]
    private let tint: Color

    /// - Parameters:
    ///   - pixels: 프레임 픽셀 데이터
    ///   - tint: 틴트 색상
    ///   - opacity: 투명도
    init(pixels: [[Color?]], tint: Color, opacity: Double) {
        self.pixels = pixels
        self.tint = tint
        self.opacity = opacity
    }

    func render() -> [[Color?]] {
        // 틴트는 나중에 blend 단계에서 적용 예정
        // 지금은 그냥 픽셀 반환
        return pixels
    }
}

// MARK: - OverlayLayer

/// 오버레이 레이어 (Grid, Guides 등 - 실제로는 SwiftUI에서 렌더링)
/// 이 레이어는 실제 픽셀을 반환하지 않고, 마커 역할만 함
class OverlayLayer: CanvasCompositeLayer {
    let id = UUID()
    let zIndex: Int = 10000  // 최상위
    var opacity: Double = 1.0
    var isVisible: Bool = true
    let blendMode: CompositeBlendMode = .normal

    enum OverlayType {
        case grid
        case guides
    }

    private let type: OverlayType
    private let canvasWidth: Int
    private let canvasHeight: Int

    init(type: OverlayType, canvasWidth: Int, canvasHeight: Int) {
        self.type = type
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
    }

    func render() -> [[Color?]] {
        // 오버레이는 실제 픽셀을 생성하지 않음 (SwiftUI Canvas로 그려짐)
        return Array(repeating: Array(repeating: nil, count: canvasWidth), count: canvasHeight)
    }
}
