//
//  CommandManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-10.
//

import Foundation
import Combine

/// Undo/Redo 시스템을 관리하는 중앙 관리자
/// Command 패턴을 사용하여 모든 작업을 추적하고 되돌릴 수 있게 합니다
class CommandManager: ObservableObject {
    /// Undo 가능한 명령 스택
    @Published private(set) var undoStack: [Command] = []

    /// Redo 가능한 명령 스택
    @Published private(set) var redoStack: [Command] = []

    /// 메모리 최적화를 위한 최대 히스토리 개수
    private let maxHistorySize: Int = 100

    /// Undo 가능 여부
    var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Redo 가능 여부
    var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// 명령을 실행하고 히스토리에 추가합니다
    /// - Parameter command: 실행할 명령
    func performCommand(_ command: Command) {
        command.execute()
        undoStack.append(command)

        // 새 명령 실행 시 redo 스택 초기화
        redoStack.removeAll()

        // 최대 히스토리 크기 유지
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
    }

    /// 이미 실행된 명령을 히스토리에 추가합니다 (execute 호출 안 함)
    /// - Parameter command: 이미 실행된 명령
    func addExecutedCommand(_ command: Command) {
        undoStack.append(command)

        // 새 명령 실행 시 redo 스택 초기화
        redoStack.removeAll()

        // 최대 히스토리 크기 유지
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst()
        }
    }

    /// 마지막 명령을 취소하고 이전 상태로 되돌립니다
    func undo() {
        guard let command = undoStack.popLast() else { return }
        command.undo()
        redoStack.append(command)
    }

    /// 마지막으로 취소한 명령을 다시 실행합니다
    func redo() {
        guard let command = redoStack.popLast() else { return }
        command.execute()
        undoStack.append(command)
    }

    /// 모든 히스토리를 초기화합니다
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// 현재 히스토리 상태를 디버깅용으로 출력합니다
    func printHistory() {
        print("=== Command History ===")
        print("Undo Stack (\(undoStack.count)):")
        for (index, command) in undoStack.enumerated() {
            print("  \(index): \(command.description)")
        }
        print("Redo Stack (\(redoStack.count)):")
        for (index, command) in redoStack.enumerated() {
            print("  \(index): \(command.description)")
        }
        print("======================")
    }
}
