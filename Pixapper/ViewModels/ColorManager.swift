//
//  ColorManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI
import Combine

/// 애플리케이션 전역 색상 관리자
/// Primary/Secondary 색상, 최근 사용 색상, 커스텀 팔레트를 관리합니다.
class ColorManager: ObservableObject {
    /// 주 색상 (그리기에 사용)
    @Published var primaryColor: Color = .black

    /// 보조 색상 (오른클릭, 대체 색상)
    @Published var secondaryColor: Color = .white

    /// 최근 사용한 색상 (최대 8개)
    @Published var recentColors: [Color] = []

    /// 커스텀 팔레트 (프로젝트별로 저장 가능)
    @Published var palette: [Color] = []

    /// 최근 색상 최대 개수
    private let maxRecentColors = 8

    /// 팔레트 최대 개수
    let maxPaletteColors = 64

    /// UserDefaults 키
    private let recentColorsKey = "ColorManager.RecentColors"

    init() {
        // 기본 팔레트 설정 (일반적인 픽셀 아트 색상)
        palette = [
            Color(red: 0, green: 0, blue: 0),           // Black
            Color(red: 1, green: 1, blue: 1),           // White
            Color(red: 0.5, green: 0.5, blue: 0.5),     // Gray
            Color(red: 1, green: 0, blue: 0),           // Red
            Color(red: 0, green: 1, blue: 0),           // Green
            Color(red: 0, green: 0, blue: 1),           // Blue
            Color(red: 1, green: 1, blue: 0),           // Yellow
            Color(red: 1, green: 0.5, blue: 0),         // Orange
            Color(red: 0.5, green: 0, blue: 0.5),       // Purple
            Color(red: 0, green: 0.5, blue: 0.5),       // Cyan
            Color(red: 0.5, green: 0.25, blue: 0),      // Brown
            Color(red: 1, green: 0.75, blue: 0.8),      // Pink
        ]

        // 저장된 최근 색상 로드
        loadRecentColors()
    }

    // MARK: - Color Operations

    /// Primary와 Secondary 색상을 교체합니다 (단축키: X)
    func swapColors() {
        Task { @MainActor in
            let temp = primaryColor
            primaryColor = secondaryColor
            secondaryColor = temp
        }
    }

    /// 기본 색상으로 리셋 (Black/White)
    func resetToDefaults() {
        primaryColor = .black
        secondaryColor = .white
    }

    /// 최근 사용 색상에 추가
    /// - Parameter color: 추가할 색상
    func addToRecent(_ color: Color) {
        // Clear 색상은 추가하지 않음
        if color == .clear {
            return
        }

        // 이미 있는 색상이면 제거 (맨 앞으로 이동하기 위해)
        recentColors.removeAll { $0.isEqual(to: color, tolerance: 0.01) }

        // 맨 앞에 추가
        recentColors.insert(color, at: 0)

        // 최대 개수 유지
        if recentColors.count > maxRecentColors {
            recentColors = Array(recentColors.prefix(maxRecentColors))
        }

        // UserDefaults에 저장
        saveRecentColors()
    }

    /// Primary 색상 설정 및 최근 목록에 추가
    /// - Parameter color: 새 Primary 색상
    func setPrimaryColor(_ color: Color) {
        primaryColor = color
        addToRecent(color)
    }

    /// Secondary 색상 설정
    /// - Parameter color: 새 Secondary 색상
    func setSecondaryColor(_ color: Color) {
        secondaryColor = color
        addToRecent(color)
    }

    // MARK: - Palette Operations

    /// 팔레트에 색상 추가
    /// - Parameter color: 추가할 색상
    /// - Returns: 추가 성공 여부 (최대 개수 초과 시 false)
    @discardableResult
    func addToPalette(_ color: Color) -> Bool {
        // 최대 개수 체크만 수행 (중복 체크 제거 - 사용자가 원하면 같은 색 여러 번 추가 가능)
        guard palette.count < maxPaletteColors else {
            return false
        }

        palette.append(color)
        return true
    }

    /// 팔레트에서 색상 제거
    /// - Parameter index: 제거할 색상의 인덱스
    func removeFromPalette(at index: Int) {
        guard index >= 0 && index < palette.count else { return }
        palette.remove(at: index)
    }

    /// 팔레트 색상 교체
    /// - Parameters:
    ///   - index: 교체할 위치
    ///   - color: 새 색상
    func updatePalette(at index: Int, with color: Color) {
        guard index >= 0 && index < palette.count else { return }
        palette[index] = color
    }

    /// 팔레트 전체 설정 (프로젝트 로드 시 사용)
    /// - Parameter colors: 새 팔레트 색상 배열
    func setPalette(_ colors: [Color]) {
        palette = colors
    }

    // MARK: - Persistence

    /// 최근 색상을 UserDefaults에 저장
    private func saveRecentColors() {
        let colorData = recentColors.compactMap { color -> [String: Double]? in
            guard let components = color.cgColor?.components,
                  components.count >= 3 else { return nil }
            return [
                "r": Double(components[0]),
                "g": Double(components[1]),
                "b": Double(components[2]),
                "a": components.count >= 4 ? Double(components[3]) : 1.0
            ]
        }
        UserDefaults.standard.set(colorData, forKey: recentColorsKey)
    }

    /// UserDefaults에서 최근 색상 로드
    private func loadRecentColors() {
        guard let colorData = UserDefaults.standard.array(forKey: recentColorsKey) as? [[String: Double]] else {
            return
        }

        recentColors = colorData.compactMap { dict in
            guard let r = dict["r"],
                  let g = dict["g"],
                  let b = dict["b"] else { return nil }
            let a = dict["a"] ?? 1.0
            return Color(red: r, green: g, blue: b, opacity: a)
        }
    }
}

