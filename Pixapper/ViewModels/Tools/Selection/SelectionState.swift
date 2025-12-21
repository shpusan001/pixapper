//
//  SelectionState.swift
//  Pixapper
//

import SwiftUI

/// 선택 도구의 내부 상태를 관리하는 구조체
/// 기존 SelectionTool에 산재되어 있던 14개의 private 상태 변수를 통합
struct SelectionState {
    // MARK: - Drawing State
    var shapeStartPoint: (x: Int, y: Int)?
    var lastDrawPoint: (x: Int, y: Int)?

    // MARK: - Resize State
    var resizeStartRect: CGRect?
    var resizeStartPixels: PixelGrid?
    var resizeStartMask: [[Bool]]?

    // MARK: - Move State
    var moveStartRect: CGRect?

    // MARK: - Rotate State
    var rotateStartAngle: Double = 0
    var rotateStartPixels: PixelGrid?
    var rotateStartMask: [[Bool]]?
    var currentRotationAngle: Double = 0

    // MARK: - Transform Accumulation
    var accumulatedRotation: Double = 0
    var accumulatedScale: CGSize = CGSize(width: 1.0, height: 1.0)

    // MARK: - Keyboard State
    var shiftPressed: Bool = false

    // MARK: - Initialization
    init() {}

    // MARK: - State Reset

    /// 모든 변환 상태 초기화 (새 캡처 시 또는 커밋 후)
    mutating func resetTransformState() {
        accumulatedRotation = 0
        accumulatedScale = CGSize(width: 1.0, height: 1.0)
    }

    /// 이동 상태 초기화
    mutating func resetMoveState() {
        lastDrawPoint = nil
        moveStartRect = nil
    }

    /// 크기 조절 상태 초기화
    mutating func resetResizeState() {
        resizeStartRect = nil
        resizeStartPixels = nil
        resizeStartMask = nil
        lastDrawPoint = nil
    }

    /// 회전 상태 초기화
    mutating func resetRotateState() {
        rotateStartPixels = nil
        rotateStartMask = nil
        rotateStartAngle = 0
        currentRotationAngle = 0
        lastDrawPoint = nil
    }

    /// 그리기 상태 초기화
    mutating func resetDrawingState() {
        shapeStartPoint = nil
        lastDrawPoint = nil
    }

    /// 전체 상태 초기화
    mutating func reset() {
        resetDrawingState()
        resetMoveState()
        resetResizeState()
        resetRotateState()
        resetTransformState()
    }
}

// MARK: - Selection Clipboard

struct SelectionClipboard {
    let pixels: PixelGrid
    let width: Int
    let height: Int
}
