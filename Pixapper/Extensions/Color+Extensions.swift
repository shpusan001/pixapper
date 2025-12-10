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
    ///   - tolerance: 허용 오차 (기본값 0.001)
    /// - Returns: 두 색상이 유사하면 true
    func isEqual(to other: Color, tolerance: Double = 0.001) -> Bool {
        guard let rgb1 = self.rgbComponents(),
              let rgb2 = other.rgbComponents() else {
            return false
        }

        return abs(rgb1.r - rgb2.r) < tolerance &&
               abs(rgb1.g - rgb2.g) < tolerance &&
               abs(rgb1.b - rgb2.b) < tolerance &&
               abs(rgb1.a - rgb2.a) < tolerance
    }
}
