//
//  ChangePaletteColorCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI

/// 팔레트 색상 변경 Command (Undo/Redo 지원)
class ChangePaletteColorCommand: Command {
    private weak var paletteManager: PaletteManager?
    private let colorIndex: UInt8
    private let oldColor: Color
    private let newColor: Color

    var description: String {
        "Change palette color at index \(colorIndex)"
    }

    init(paletteManager: PaletteManager, index: UInt8, oldColor: Color, newColor: Color) {
        self.paletteManager = paletteManager
        self.colorIndex = index
        self.oldColor = oldColor
        self.newColor = newColor
    }

    func execute() {
        guard let paletteManager = paletteManager else { return }
        paletteManager.updateColor(at: colorIndex, to: newColor)
    }

    func undo() {
        guard let paletteManager = paletteManager else { return }
        paletteManager.updateColor(at: colorIndex, to: oldColor)
    }
}
