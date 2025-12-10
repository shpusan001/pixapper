//
//  Command.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation

/// Command 패턴의 기본 프로토콜
/// 모든 실행 가능한 작업(그리기, 레이어 조작, 프레임 조작 등)은 이 프로토콜을 구현
protocol Command {
    /// 명령을 실행합니다
    func execute()

    /// 명령을 취소하고 이전 상태로 되돌립니다
    func undo()

    /// 명령에 대한 설명 (디버깅 및 UI 표시용)
    var description: String { get }
}
