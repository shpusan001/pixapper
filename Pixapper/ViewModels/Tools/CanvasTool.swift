//
//  CanvasTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 캔버스 도구 공통 인터페이스
@MainActor
protocol CanvasTool {
    /// 도구 다운 이벤트
    func handleDown(x: Int, y: Int, altPressed: Bool)

    /// 도구 드래그 이벤트
    func handleDrag(x: Int, y: Int)

    /// 도구 업 이벤트
    func handleUp(x: Int, y: Int)

    /// 호버 업데이트 (선택적)
    func updateHover(x: Int, y: Int)

    /// 호버 클리어 (선택적)
    func clearHover()

    /// 캔버스 바깥 클릭 처리 (선택적)
    func handleOutsideClick()
}

/// CanvasTool 프로토콜의 기본 구현 (선택적 메서드)
extension CanvasTool {
    func updateHover(x: Int, y: Int) {}
    func clearHover() {}
    func handleOutsideClick() {}
}
