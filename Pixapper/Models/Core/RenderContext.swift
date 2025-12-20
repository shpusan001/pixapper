//
//  RenderContext.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

/// 렌더링 컨텍스트 프로토콜
/// PixelValue를 실제 색상으로 변환하는 역할
protocol RenderContext {
    var palette: ColorPalette { get }
    var gradients: GradientLibrary { get }

    /// PixelValue → Color 변환 (단일 픽셀, 좌표 없음)
    /// - Parameter pixel: 픽셀 값
    /// - Returns: 색상 (투명이면 nil)
    func resolve(_ pixel: PixelValue) -> Color?

    /// PixelValue → Color 변환 (그라디언트 고려, 좌표 필요)
    /// - Parameters:
    ///   - pixel: 픽셀 값
    ///   - point: 픽셀 좌표
    /// - Returns: 색상 (투명이면 nil)
    func resolve(_ pixel: PixelValue, at point: PixelPoint) -> Color?
}

/// 기본 렌더링 컨텍스트 구현
struct DefaultRenderContext: RenderContext {
    let palette: ColorPalette
    let gradients: GradientLibrary

    init(palette: ColorPalette, gradients: GradientLibrary = GradientLibrary()) {
        self.palette = palette
        self.gradients = gradients
    }

    func resolve(_ pixel: PixelValue) -> Color? {
        switch pixel {
        case .transparent:
            return nil

        case .indexed(let index):
            return palette[index]

        case .gradient:
            // 좌표 없이는 그라디언트 렌더링 불가
            // 첫 번째 정지점 색상 반환 (fallback)
            return nil
        }
    }

    func resolve(_ pixel: PixelValue, at point: PixelPoint) -> Color? {
        switch pixel {
        case .transparent:
            return nil

        case .indexed(let index):
            return palette[index]

        case .gradient(let id):
            guard let gradient = gradients[id] else { return nil }
            return interpolateGradient(gradient, at: point)
        }
    }

    /// 그라디언트 보간
    /// - Parameters:
    ///   - gradient: 그라디언트 정의
    ///   - point: 픽셀 좌표
    /// - Returns: 보간된 색상
    private func interpolateGradient(_ gradient: GradientDefinition, at point: PixelPoint) -> Color? {
        guard !gradient.stops.isEmpty else { return nil }

        // 그라디언트 타입에 따라 위치 계산
        let position: Double
        switch gradient.type {
        case .linear:
            position = calculateLinearPosition(gradient, at: point)
        case .radial:
            position = calculateRadialPosition(gradient, at: point)
        case .angular:
            position = calculateAngularPosition(gradient, at: point)
        }

        // 정지점 사이 보간
        return interpolateColor(in: gradient.stops, at: position)
    }

    /// 선형 그라디언트 위치 계산
    private func calculateLinearPosition(_ gradient: GradientDefinition, at point: PixelPoint) -> Double {
        // NOTE: 캔버스 크기를 모르므로 256x256 가정 (표준 픽셀 아트 크기)
        // TODO: RenderContext에 bounds 추가 시 정확한 계산으로 교체
        let canvasSize = 256.0

        let angle = gradient.angle ?? 0
        let angleRad = angle * .pi / 180.0

        // 정규화된 좌표 (0.0 ~ 1.0)
        let normalizedX = Double(point.x) / canvasSize
        let normalizedY = Double(point.y) / canvasSize

        // 중심점 기준 좌표 (-0.5 ~ 0.5)
        let cx = normalizedX - 0.5
        let cy = normalizedY - 0.5

        // 각도 방향으로 투영 (벡터 내적)
        // angle=0은 오른쪽, angle=90은 아래
        let directionX = cos(angleRad)
        let directionY = sin(angleRad)
        let projection = cx * directionX + cy * directionY

        // -0.5 ~ 0.5 범위를 0.0 ~ 1.0으로 변환
        return min(max(projection + 0.5, 0.0), 1.0)
    }

    /// 방사형 그라디언트 위치 계산
    private func calculateRadialPosition(_ gradient: GradientDefinition, at point: PixelPoint) -> Double {
        // NOTE: 캔버스 크기를 모르므로 256x256 가정
        // TODO: RenderContext에 bounds 추가 시 정확한 계산으로 교체
        let canvasSize = 256.0

        let centerX = gradient.centerX ?? 0.5
        let centerY = gradient.centerY ?? 0.5
        let radius = gradient.radius ?? 0.5

        // 정규화된 좌표 (0.0 ~ 1.0)
        let normalizedX = Double(point.x) / canvasSize
        let normalizedY = Double(point.y) / canvasSize

        // 중심점으로부터의 거리 계산
        let dx = normalizedX - centerX
        let dy = normalizedY - centerY
        let distance = sqrt(dx * dx + dy * dy)

        // radius로 정규화 (0.0 ~ 1.0)
        let normalizedDistance = distance / radius

        return min(max(normalizedDistance, 0.0), 1.0)
    }

    /// 각도 그라디언트 위치 계산
    private func calculateAngularPosition(_ gradient: GradientDefinition, at point: PixelPoint) -> Double {
        // NOTE: 캔버스 크기를 모르므로 256x256 가정
        // TODO: RenderContext에 bounds 추가 시 정확한 계산으로 교체
        let canvasSize = 256.0

        let centerX = gradient.centerX ?? 0.5
        let centerY = gradient.centerY ?? 0.5

        // 정규화된 좌표 (0.0 ~ 1.0)
        let normalizedX = Double(point.x) / canvasSize
        let normalizedY = Double(point.y) / canvasSize

        // 중심점으로부터의 벡터
        let dx = normalizedX - centerX
        let dy = normalizedY - centerY

        // 각도 계산 (atan2는 -π ~ π 반환)
        let angle = atan2(dy, dx)

        // 0 ~ 2π로 변환
        let normalizedAngle = angle < 0 ? angle + 2 * .pi : angle

        // 0.0 ~ 1.0으로 정규화
        return normalizedAngle / (2 * .pi)
    }

    /// 색상 보간 (정지점 사이)
    /// - Parameters:
    ///   - stops: 그라디언트 정지점들
    ///   - position: 보간 위치 (0.0 ~ 1.0)
    /// - Returns: 보간된 색상
    private func interpolateColor(in stops: [GradientStop], at position: Double) -> Color? {
        // 범위 밖이면 끝 색상 반환
        if position <= stops.first!.position {
            return palette[stops.first!.colorIndex]
        }
        if position >= stops.last!.position {
            return palette[stops.last!.colorIndex]
        }

        // 두 정지점 사이 찾기
        for i in 0..<(stops.count - 1) {
            let stop1 = stops[i]
            let stop2 = stops[i + 1]

            if position >= stop1.position && position <= stop2.position {
                // 보간 비율 계산
                let range = stop2.position - stop1.position
                let t = (position - stop1.position) / range

                // 두 색상 보간
                guard let color1 = palette[stop1.colorIndex],
                      let color2 = palette[stop2.colorIndex] else {
                    return nil
                }

                return interpolateColors(color1, color2, t: t)
            }
        }

        return nil
    }

    /// 두 색상 사이 선형 보간
    /// - Parameters:
    ///   - color1: 시작 색상
    ///   - color2: 끝 색상
    ///   - t: 보간 비율 (0.0 ~ 1.0)
    /// - Returns: 보간된 색상
    private func interpolateColors(_ color1: Color, _ color2: Color, t: Double) -> Color? {
        guard let rgb1 = color1.rgbComponents(),
              let rgb2 = color2.rgbComponents() else {
            return nil
        }

        let r = rgb1.r + (rgb2.r - rgb1.r) * t
        let g = rgb1.g + (rgb2.g - rgb1.g) * t
        let b = rgb1.b + (rgb2.b - rgb1.b) * t
        let a = rgb1.a + (rgb2.a - rgb1.a) * t

        return Color(red: r, green: g, blue: b, opacity: a)
    }
}
