//
//  SerializableColor.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// SwiftUI Color를 Codable 형태로 저장하기 위한 구조체
struct SerializableColor: Codable, Equatable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    /// SwiftUI Color로부터 직렬화 가능한 색상 생성
    init(from color: Color) {
        #if os(macOS)
        // NSColor로 변환하여 RGB 컴포넌트 추출
        if let nsColor = NSColor(color).usingColorSpace(.sRGB) {
            self.red = Double(nsColor.redComponent)
            self.green = Double(nsColor.greenComponent)
            self.blue = Double(nsColor.blueComponent)
            self.alpha = Double(nsColor.alphaComponent)
        } else {
            // 변환 실패 시 기본값 (투명)
            self.red = 0
            self.green = 0
            self.blue = 0
            self.alpha = 0
        }
        #else
        // iOS용 (현재는 macOS만 지원)
        let components = UIColor(color).cgColor.components ?? [0, 0, 0, 0]
        self.red = Double(components[0])
        self.green = Double(components[1])
        self.blue = Double(components[2])
        self.alpha = Double(components[3])
        #endif
    }

    /// RGB 컴포넌트로 직접 초기화
    init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// SwiftUI Color로 변환
    func toColor() -> Color {
        Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

/// Optional Color를 직렬화하기 위한 헬퍼 extension
extension Array where Element == [Color?] {
    /// [[Color?]] → [[SerializableColor?]]
    func toSerializable() -> [[SerializableColor?]] {
        self.map { row in
            row.map { color in
                color.map { SerializableColor(from: $0) }
            }
        }
    }
}

extension Array where Element == [SerializableColor?] {
    /// [[SerializableColor?]] → [[Color?]]
    func toColors() -> [[Color?]] {
        self.map { row in
            row.map { serializableColor in
                serializableColor?.toColor()
            }
        }
    }

    /// [[SerializableColor?]] → PixelGrid (마이그레이션용)
    /// - Parameter palette: 색상을 인덱스로 변환할 팔레트 (기본값: 기본 팔레트)
    func toPixelGrid(palette: ColorPalette = ColorPalette.default) -> PixelGrid {
        self.map { row in
            row.map { serializableColor in
                if let color = serializableColor?.toColor() {
                    // 팔레트에서 가장 가까운 색상 찾기
                    if let index = palette.findClosest(color) {
                        return .indexed(index)
                    }
                }
                return .transparent
            }
        }
    }
}

/// PixelGrid를 직렬화하기 위한 헬퍼 extension
extension Array where Element == [PixelValue] {
    /// PixelGrid → [[SerializableColor?]] (저장용)
    /// - Parameter palette: 인덱스를 색상으로 변환할 팔레트 (기본값: 기본 팔레트)
    func toSerializable(palette: ColorPalette = ColorPalette.default) -> [[SerializableColor?]] {
        self.map { row in
            row.map { pixelValue -> SerializableColor? in
                switch pixelValue {
                case .transparent:
                    return nil
                case .indexed(let colorIndex):
                    // 팔레트에서 색상 가져오기
                    if let color = palette.getColor(at: colorIndex) {
                        return SerializableColor(from: color)
                    }
                    return nil
                case .gradient:
                    // 그라디언트는 아직 미구현, 투명으로 처리
                    return nil
                case .directColor(let rgba8):
                    // RGB 직접 저장된 색상을 SerializableColor로 변환
                    let color = Color(
                        red: Double(rgba8.r) / 255.0,
                        green: Double(rgba8.g) / 255.0,
                        blue: Double(rgba8.b) / 255.0,
                        opacity: Double(rgba8.a) / 255.0
                    )
                    return SerializableColor(from: color)
                }
            }
        }
    }
}
