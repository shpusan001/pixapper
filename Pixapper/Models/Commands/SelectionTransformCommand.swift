//
//  SelectionTransformCommand.swift
//  Pixapper
//
//  Created by Claude on 2025-12-12.
//

import SwiftUI

/// 선택 영역 변형 커맨드 (회전, 뒤집기, 크기 조절 등)
class SelectionTransformCommand: Command {
    private weak var canvasViewModel: CanvasViewModel?
    private let oldPixels: [[Color?]]
    private let newPixels: [[Color?]]
    private let oldRect: CGRect
    private let newRect: CGRect

    var description: String {
        return "Selection Transform"
    }

    init(canvasViewModel: CanvasViewModel, oldPixels: [[Color?]], newPixels: [[Color?]], oldRect: CGRect, newRect: CGRect) {
        self.canvasViewModel = canvasViewModel
        self.oldPixels = oldPixels
        self.newPixels = newPixels
        self.oldRect = oldRect
        self.newRect = newRect
    }

    func execute() {
        canvasViewModel?.applyTransformFromCommand(pixels: newPixels, rect: newRect)
    }

    func undo() {
        canvasViewModel?.applyTransformFromCommand(pixels: oldPixels, rect: oldRect)
    }
}
