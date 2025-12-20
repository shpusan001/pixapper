//
//  PixelValue.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import Foundation

/// 팔레트 기반 그래디언트 픽셀 (동적 색상)
struct PaletteGradientPixel: Codable, Hashable, Sendable {
    let startIndex: UInt8  // 시작 팔레트 인덱스
    let endIndex: UInt8    // 끝 팔레트 인덱스
    let position: UInt16   // 보간 위치 (0~65535, 0.0~1.0을 65536단계로)

    init(startIndex: UInt8, endIndex: UInt8, position: Double) {
        self.startIndex = startIndex
        self.endIndex = endIndex
        // Double (0.0~1.0) → UInt16 (0~65535)
        let scaled = position * 65535.0
        let clamped = max(0.0, min(65535.0, scaled))
        self.position = UInt16(clamped)
    }

    /// 보간 위치를 0.0~1.0 범위로 반환
    var normalizedPosition: Double {
        return Double(position) / 65535.0
    }
}

/// 픽셀 값 - 모든 가능한 픽셀 타입을 표현
/// 확장 가능한 설계: 새로운 픽셀 타입 추가가 쉬움
enum PixelValue: Codable, Hashable, Sendable {
    case transparent                         // 투명 픽셀
    case indexed(UInt8)                      // 팔레트 인덱스 (0-255)
    case paletteGradient(PaletteGradientPixel)  // 팔레트 기반 동적 그래디언트

    // 향후 확장 가능:
    // case pattern(UUID)               // 패턴 참조
    // case reference(LayerRef, Point)  // 다른 레이어 참조 (심볼)
}

/// 픽셀 값 배열 타입 별칭
typealias PixelGrid = [[PixelValue]]

// MARK: - PixelValue Extensions

extension PixelValue {
    /// 빈 픽셀(투명)인지 확인
    var isEmpty: Bool {
        if case .transparent = self { return true }
        return false
    }

    /// 팔레트 인덱스 추출 (있으면)
    var paletteIndex: UInt8? {
        if case .indexed(let index) = self { return index }
        return nil
    }
}

// MARK: - PixelGrid Helpers

extension Array where Element == Array<PixelValue> {
    /// 빈 픽셀 그리드 생성
    static func createEmpty(width: Int, height: Int) -> [[PixelValue]] {
        let emptyRow = [PixelValue](repeating: PixelValue.transparent, count: width)
        return [[PixelValue]](repeating: emptyRow, count: height)
    }

    /// 그리드가 비어있는지 확인 (모든 픽셀이 투명)
    var isAllEmpty: Bool {
        return allSatisfy { row in
            row.allSatisfy { $0.isEmpty }
        }
    }
}

// MARK: - Codable Implementation

extension PixelValue {
    enum CodingKeys: String, CodingKey {
        case type
        case index
        case paletteGradient
    }

    enum ValueType: String, Codable {
        case transparent
        case indexed
        case paletteGradient
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ValueType.self, forKey: .type)

        switch type {
        case .transparent:
            self = .transparent

        case .indexed:
            let index = try container.decode(UInt8.self, forKey: .index)
            self = .indexed(index)

        case .paletteGradient:
            let gradPixel = try container.decode(PaletteGradientPixel.self, forKey: .paletteGradient)
            self = .paletteGradient(gradPixel)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case .transparent:
            try container.encode(ValueType.transparent, forKey: .type)

        case .indexed(let index):
            try container.encode(ValueType.indexed, forKey: .type)
            try container.encode(index, forKey: .index)

        case .paletteGradient(let gradPixel):
            try container.encode(ValueType.paletteGradient, forKey: .type)
            try container.encode(gradPixel, forKey: .paletteGradient)
        }
    }
}
