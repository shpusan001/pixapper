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
}
