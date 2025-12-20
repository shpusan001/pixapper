//
//  ColorPalette.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

/// 색상 팔레트 (최대 256색)
/// Aseprite 스타일의 인덱스 기반 색상 관리
struct ColorPalette: Codable, Identifiable, Hashable {
    static let maxColors: Int = 256

    let id: UUID
    var name: String
    private(set) var colors: [SerializableColor]

    init(id: UUID = UUID(), name: String = "Unnamed Palette", colors: [Color] = []) {
        self.id = id
        self.name = name
        self.colors = colors.prefix(Self.maxColors).map { SerializableColor(from: $0) }
    }

    init(id: UUID = UUID(), name: String = "Unnamed Palette", serializableColors: [SerializableColor]) {
        self.id = id
        self.name = name
        self.colors = Array(serializableColors.prefix(Self.maxColors))
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ColorPalette, rhs: ColorPalette) -> Bool {
        return lhs.id == rhs.id
    }

    /// 색상 추가 (중복 체크)
    /// - Parameter color: 추가할 색상
    /// - Returns: 추가된 인덱스, 실패 시 nil
    mutating func add(_ color: Color) -> UInt8? {
        // 이미 존재하는 색상인지 확인
        if let index = findExact(color) {
            return UInt8(index)
        }

        guard colors.count < Self.maxColors else { return nil }
        colors.append(SerializableColor(from: color))
        return UInt8(colors.count - 1)
    }

    /// 정확히 일치하는 색상 찾기
    /// - Parameter color: 찾을 색상
    /// - Returns: 인덱스, 없으면 nil
    func findExact(_ color: Color) -> Int? {
        return colors.firstIndex { serializableColor in
            let paletteColor = serializableColor.toColor()
            return color.isEqual(to: paletteColor)
        }
    }

    /// 가장 가까운 색상 찾기 (Euclidean distance)
    /// - Parameter color: 찾을 색상
    /// - Returns: 가장 가까운 색상의 인덱스
    func findClosest(_ color: Color) -> UInt8? {
        guard !colors.isEmpty else { return nil }
        guard let rgb = color.rgbComponents() else { return nil }

        var closestIndex = 0
        var minDistance = Double.infinity

        for (index, serializableColor) in colors.enumerated() {
            let paletteColor = serializableColor.toColor()
            guard let paletteRgb = paletteColor.rgbComponents() else { continue }

            // Euclidean distance in RGB space
            let dr = rgb.r - paletteRgb.r
            let dg = rgb.g - paletteRgb.g
            let db = rgb.b - paletteRgb.b
            let distance = dr*dr + dg*dg + db*db

            if distance < minDistance {
                minDistance = distance
                closestIndex = index
            }
        }

        return UInt8(closestIndex)
    }

    /// 팔레트 색상 일괄 변경
    /// - Parameters:
    ///   - index: 변경할 인덱스
    ///   - newColor: 새 색상
    /// - Note: 이 변경은 자동으로 모든 픽셀에 반영됨 (인덱스 기반이므로)
    mutating func update(at index: UInt8, to newColor: Color) {
        guard Int(index) < colors.count else { return }
        colors[Int(index)] = SerializableColor(from: newColor)
    }

    /// 팔레트 색상 제거
    /// - Parameter index: 제거할 인덱스
    /// - Note: 이 작업 후 더 높은 인덱스들이 1씩 감소함. 주의 필요!
    mutating func remove(at index: UInt8) {
        guard Int(index) < colors.count else { return }
        colors.remove(at: Int(index))
    }

    /// 인덱스로 색상 가져오기
    subscript(index: UInt8) -> Color? {
        guard Int(index) < colors.count else { return nil }
        return colors[Int(index)].toColor()
    }

    /// Color 배열로 변환 (UI 표시용)
    var colorArray: [Color] {
        return colors.map { $0.toColor() }
    }

    /// 팔레트 크기
    var count: Int {
        return colors.count
    }

    /// 빈 팔레트인지 확인
    var isEmpty: Bool {
        return colors.isEmpty
    }

    /// 인덱스로 색상 가져오기 (메서드 버전)
    /// - Parameter index: 색상 인덱스
    /// - Returns: 색상, 없으면 nil
    func getColor(at index: UInt8) -> Color? {
        return self[index]
    }
}

// MARK: - Palette Presets

extension ColorPalette {
    /// 기본 팔레트 (16색)
    static var `default`: ColorPalette {
        return default16()
    }

    /// 기본 16색 팔레트
    static func default16() -> ColorPalette {
        let colors: [Color] = [
            .black,
            Color(red: 0.5, green: 0.5, blue: 0.5),  // 회색
            .white,
            .red,
            Color(red: 1.0, green: 0.5, blue: 0.0),  // 주황
            .yellow,
            Color(red: 0.5, green: 1.0, blue: 0.0),  // 연두
            .green,
            Color(red: 0.0, green: 1.0, blue: 0.5),  // 청록
            .cyan,
            Color(red: 0.0, green: 0.5, blue: 1.0),  // 하늘
            .blue,
            Color(red: 0.5, green: 0.0, blue: 1.0),  // 남보라
            .purple,
            .pink,
            Color(red: 1.0, green: 0.0, blue: 0.5)   // 자주
        ]
        return ColorPalette(name: "Default 16", colors: colors)
    }

    /// DB32 팔레트 (유명한 32색 픽셀 아트 팔레트)
    static func db32() -> ColorPalette {
        let hexColors = [
            "000000", "222034", "45283c", "663931", "8f563b", "df7126", "d9a066", "eec39a",
            "fbf236", "99e550", "6abe30", "37946e", "4b692f", "524b24", "323c39", "3f3f74",
            "306082", "5b6ee1", "639bff", "5fcde4", "cbdbfc", "ffffff", "9badb7", "847e87",
            "696a6a", "595652", "76428a", "ac3232", "d95763", "d77bba", "8f974a", "8a6f30"
        ]

        let colors = hexColors.compactMap { hex -> Color? in
            return Color(hex: hex)
        }

        return ColorPalette(name: "DB32", colors: colors)
    }

    /// 그레이스케일 팔레트 (16단계)
    static func grayscale16() -> ColorPalette {
        let colors = (0..<16).map { i -> Color in
            let gray = Double(i) / 15.0
            return Color(red: gray, green: gray, blue: gray)
        }
        return ColorPalette(name: "Grayscale 16", colors: colors)
    }

    /// 모든 프리셋 팔레트
    static var presets: [ColorPalette] {
        return [default16(), db32(), grayscale16()]
    }
}

// MARK: - Serialization

extension ColorPalette {
    /// ColorPalette → [SerializableColor] 변환
    func toSerializableColors() -> [SerializableColor] {
        return colors
    }

    /// [SerializableColor] → ColorPalette 변환
    static func fromSerializableColors(_ colors: [SerializableColor], id: UUID = UUID(), name: String = "Custom Palette") -> ColorPalette {
        return ColorPalette(id: id, name: name, serializableColors: colors)
    }
}

// MARK: - Color Hex Extension

extension Color {
    /// HEX 문자열로 Color 생성
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0

        guard Scanner(string: hex).scanHexInt64(&int) else { return nil }

        let r, g, b: Double
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        default:
            return nil
        }

        self.init(red: r, green: g, blue: b)
    }
}
