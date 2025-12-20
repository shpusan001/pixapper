//
//  Color+Extensions.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/10/25.
//

import SwiftUI
import AppKit

extension Color {
    /// RGB 컴포넌트 추출
    /// - Returns: (r, g, b, a) 값 (0.0 ~ 1.0 범위), 실패 시 nil
    func rgbComponents() -> (r: Double, g: Double, b: Double, a: Double)? {
        guard let components = NSColor(self).cgColor.components else { return nil }

        // CGColor 컴포넌트 개수에 따라 처리 (CGFloat를 Double로 변환)
        if components.count >= 4 {
            return (Double(components[0]), Double(components[1]), Double(components[2]), Double(components[3]))
        } else if components.count >= 3 {
            return (Double(components[0]), Double(components[1]), Double(components[2]), 1.0)
        } else {
            // 그레이스케일 등
            return (Double(components[0]), Double(components[0]), Double(components[0]), components.count > 1 ? Double(components[1]) : 1.0)
        }
    }

    /// 다른 Color와의 정밀한 비교
    /// - Parameters:
    ///   - other: 비교할 Color
    ///   - tolerance: 허용 오차 (기본값 Constants.Color.defaultTolerance)
    /// - Returns: 두 색상이 유사하면 true
    func isEqual(to other: Color, tolerance: Double = Constants.Color.defaultTolerance) -> Bool {
        guard let rgb1 = self.rgbComponents(),
              let rgb2 = other.rgbComponents() else {
            return false
        }

        return abs(rgb1.r - rgb2.r) < tolerance &&
               abs(rgb1.g - rgb2.g) < tolerance &&
               abs(rgb1.b - rgb2.b) < tolerance &&
               abs(rgb1.a - rgb2.a) < tolerance
    }

    /// 두 Color 옵셔널의 비교 (nil 처리 포함)
    /// - Parameters:
    ///   - c1: 첫 번째 색상 (optional)
    ///   - c2: 두 번째 색상 (optional)
    ///   - tolerance: 허용 오차 (기본값 Constants.Color.defaultTolerance)
    /// - Returns: 두 색상이 같으면 true (둘 다 nil이면 true)
    static func areEqual(_ c1: Color?, _ c2: Color?, tolerance: Double = Constants.Color.defaultTolerance) -> Bool {
        if c1 == nil && c2 == nil {
            return true
        }
        guard let c1 = c1, let c2 = c2 else {
            return false
        }
        return c1.isEqual(to: c2, tolerance: tolerance)
    }

    /// HSV 컴포넌트 추출
    /// - Returns: (h: 0-1, s: 0-1, v: 0-1) 또는 nil
    func hsvComponents() -> (h: Double, s: Double, v: Double)? {
        guard let rgb = rgbComponents() else { return nil }

        let r = rgb.r
        let g = rgb.g
        let b = rgb.b

        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        var h: Double = 0
        let s: Double = maxC == 0 ? 0 : delta / maxC
        let v: Double = maxC

        if delta != 0 {
            if maxC == r {
                h = (g - b) / delta + (g < b ? 6 : 0)
            } else if maxC == g {
                h = (b - r) / delta + 2
            } else {
                h = (r - g) / delta + 4
            }
            h /= 6
        }

        return (h: h, s: s, v: v)
    }

    /// HSV 값으로 Color 생성
    /// - Parameters:
    ///   - h: Hue (0-1)
    ///   - s: Saturation (0-1)
    ///   - v: Value/Brightness (0-1)
    /// - Returns: Color
    static func fromHSV(h: Double, s: Double, v: Double) -> Color {
        let h = h.clamped(to: 0...1)
        let s = s.clamped(to: 0...1)
        let v = v.clamped(to: 0...1)

        let i = Int(h * 6)
        let f = h * 6 - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - f * s)
        let t = v * (1 - (1 - f) * s)

        let r: Double, g: Double, b: Double

        switch i % 6 {
        case 0: (r, g, b) = (v, t, p)
        case 1: (r, g, b) = (q, v, p)
        case 2: (r, g, b) = (p, v, t)
        case 3: (r, g, b) = (p, q, v)
        case 4: (r, g, b) = (t, p, v)
        default: (r, g, b) = (v, p, q)
        }

        return Color(red: r, green: g, blue: b)
    }

    /// 색상의 상대 휘도 계산 (0.0 ~ 1.0)
    /// - Returns: 휘도 값 (어두우면 0에 가깝고, 밝으면 1에 가까움)
    /// - Note: W3C WCAG 2.0 권장 공식 사용
    func luminance() -> Double {
        guard let rgb = rgbComponents() else { return 0.5 }

        // sRGB to linear RGB conversion
        let linearize = { (component: Double) -> Double in
            if component <= 0.03928 {
                return component / 12.92
            } else {
                return pow((component + 0.055) / 1.055, 2.4)
            }
        }

        let r = linearize(rgb.r)
        let g = linearize(rgb.g)
        let b = linearize(rgb.b)

        // Relative luminance formula
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    /// 배경색에 대한 최적의 대비 색상 반환 (흰색 또는 검은색)
    /// - Returns: 배경이 어두우면 흰색, 밝으면 검은색
    func contrastColor() -> Color {
        return luminance() > 0.5 ? .black : .white
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
