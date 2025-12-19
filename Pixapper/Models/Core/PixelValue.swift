//
//  PixelValue.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import Foundation

/// 픽셀 값 - 모든 가능한 픽셀 타입을 표현
/// 확장 가능한 설계: 새로운 픽셀 타입 추가가 쉬움
enum PixelValue: Codable, Hashable, Sendable {
    case transparent                    // 투명 픽셀
    case indexed(UInt8)                 // 팔레트 인덱스 (0-255)
    case gradient(UUID)                 // 그라디언트 참조

    // 향후 확장 가능:
    // case pattern(UUID)               // 패턴 참조
    // case directColor(RGBA8)          // 직접 색상 (팔레트 외)
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

    /// 그라디언트 ID 추출 (있으면)
    var gradientId: UUID? {
        if case .gradient(let id) = self { return id }
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
        case gradientId
    }

    enum ValueType: String, Codable {
        case transparent
        case indexed
        case gradient
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

        case .gradient:
            let id = try container.decode(UUID.self, forKey: .gradientId)
            self = .gradient(id)
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

        case .gradient(let id):
            try container.encode(ValueType.gradient, forKey: .type)
            try container.encode(id, forKey: .gradientId)
        }
    }
}
