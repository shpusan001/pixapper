//
//  PaletteManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI
import Combine

/// 여러 팔레트를 관리하는 매니저
/// Single Source of Truth for palettes
@MainActor
class PaletteManager: ObservableObject {
    @Published private(set) var palettes: [UUID: ColorPalette] = [:]
    @Published var currentPaletteId: UUID

    /// 현재 선택된 팔레트
    var currentPalette: ColorPalette {
        get {
            return palettes[currentPaletteId] ?? ColorPalette.default
        }
        set {
            palettes[currentPaletteId] = newValue
        }
    }

    /// 팔레트 목록 (정렬된)
    var paletteList: [ColorPalette] {
        return Array(palettes.values).sorted { $0.name < $1.name }
    }

    init(initialPalette: ColorPalette? = nil) {
        let palette = initialPalette ?? ColorPalette.default
        self.currentPaletteId = palette.id
        self.palettes = [palette.id: palette]
    }

    /// ProjectDocument의 colorPalette에서 초기화
    convenience init(fromSerializableColors colors: [SerializableColor]) {
        let palette = ColorPalette.fromSerializableColors(colors, name: "Project Palette")
        self.init(initialPalette: palette)
    }

    // MARK: - Palette Management

    /// 팔레트 추가
    /// - Parameter palette: 추가할 팔레트
    func addPalette(_ palette: ColorPalette) {
        palettes[palette.id] = palette
    }

    /// 새 팔레트 생성
    /// - Parameter name: 팔레트 이름
    /// - Returns: 생성된 팔레트 ID
    @discardableResult
    func createPalette(name: String, colors: [Color] = []) -> UUID {
        let newPalette = ColorPalette(name: name, colors: colors)
        palettes[newPalette.id] = newPalette
        return newPalette.id
    }

    /// 팔레트 복제
    /// - Parameter paletteId: 복제할 팔레트 ID
    /// - Returns: 새로 생성된 팔레트 ID
    @discardableResult
    func duplicatePalette(_ paletteId: UUID) -> UUID? {
        guard let originalPalette = palettes[paletteId] else { return nil }

        let newPalette = ColorPalette(
            name: "\(originalPalette.name) Copy",
            colors: originalPalette.colorArray
        )
        palettes[newPalette.id] = newPalette
        return newPalette.id
    }

    /// 팔레트 삭제
    /// - Parameter paletteId: 삭제할 팔레트 ID
    /// - Note: 현재 선택된 팔레트를 삭제하면 기본 팔레트로 전환됨
    func deletePalette(_ paletteId: UUID) {
        guard palettes.count > 1 else {
            print("Cannot delete the last palette")
            return
        }

        palettes.removeValue(forKey: paletteId)

        // 삭제한 팔레트가 현재 팔레트였다면 다른 팔레트로 전환
        if currentPaletteId == paletteId {
            if let firstPaletteId = palettes.keys.first {
                currentPaletteId = firstPaletteId
            }
        }
    }

    /// 팔레트 전환
    /// - Parameter paletteId: 전환할 팔레트 ID
    func switchPalette(to paletteId: UUID) {
        guard palettes[paletteId] != nil else { return }
        currentPaletteId = paletteId
    }

    /// 팔레트 이름 변경
    /// - Parameters:
    ///   - paletteId: 팔레트 ID
    ///   - newName: 새 이름
    func renamePalette(_ paletteId: UUID, to newName: String) {
        guard var palette = palettes[paletteId] else { return }
        palette.name = newName
        palettes[paletteId] = palette
    }

    // MARK: - Color Management

    /// 현재 팔레트의 색상 업데이트
    /// - Parameters:
    ///   - index: 색상 인덱스
    ///   - newColor: 새 색상
    /// - Note: 이 변경은 자동으로 모든 픽셀에 반영됨
    func updateColor(at index: UInt8, to newColor: Color) {
        var palette = currentPalette
        palette.update(at: index, to: newColor)
        palettes[currentPaletteId] = palette

        // 명시적으로 변경 알림 (즉시 UI 업데이트)
        objectWillChange.send()
    }

    /// 현재 팔레트에 색상 추가
    /// - Parameter color: 추가할 색상
    /// - Returns: 추가된 인덱스
    func addColor(_ color: Color) -> UInt8? {
        var palette = currentPalette
        let index = palette.add(color)
        palettes[currentPaletteId] = palette

        // 명시적으로 변경 알림
        objectWillChange.send()
        return index
    }

    /// 현재 팔레트의 색상 제거
    /// - Parameter index: 제거할 인덱스
    func removeColor(at index: UInt8) {
        var palette = currentPalette
        palette.remove(at: index)
        palettes[currentPaletteId] = palette

        // 명시적으로 변경 알림
        objectWillChange.send()
    }

    // MARK: - Preset Management

    /// 프리셋 팔레트 로드
    func loadPresets() {
        for preset in ColorPalette.presets {
            if palettes[preset.id] == nil {
                palettes[preset.id] = preset
            }
        }
    }
}
