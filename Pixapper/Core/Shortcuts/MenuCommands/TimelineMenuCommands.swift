//
//  TimelineMenuCommands.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

struct TimelineMenuCommands: Commands {
    @FocusedValue(\.appViewModel) private var appViewModel: AppViewModel?
    @FocusedValue(\.canvasViewModel) private var canvasViewModel: CanvasViewModel?
    @FocusedValue(\.timelineViewModel) private var timelineViewModel: TimelineViewModel?
    @FocusedValue(\.colorManager) private var colorManager: ColorManager?
    @FocusedValue(\.commandManager) private var commandManager: CommandManager?

    var body: some Commands {
        CommandMenu("Timeline") {
            // Frames (메뉴에 표시만, 단축키는 Edit 메뉴의 Copy/Cut/Paste/Delete 사용)
            shortcutButton(.copyFrames)
            shortcutButton(.cutFrames)
            shortcutButton(.pasteFrames)
            shortcutButton(.deleteFrames)

            Divider()

            // Note: Play/Pause, Next/Previous Frame, Onion Skin은
            // 단일 키 단축키라서 메뉴에 넣지 않음
            // ContentView에서 직접 처리됨
        }
    }

    // MARK: - Helper

    @ViewBuilder
    private func shortcutButton(_ shortcut: Shortcut) -> some View {
        let button = Button(shortcut.menuTitle) {
            ShortcutManager.execute(
                shortcut,
                appViewModel: appViewModel,
                canvasViewModel: canvasViewModel,
                timelineViewModel: timelineViewModel,
                colorManager: colorManager,
                commandManager: commandManager
            )
        }
        .disabled(!ShortcutManager.canExecute(
            shortcut,
            appViewModel: appViewModel,
            canvasViewModel: canvasViewModel,
            timelineViewModel: timelineViewModel,
            colorManager: colorManager,
            commandManager: commandManager
        ))

        if let keyShortcut = shortcut.defaultKeyboardShortcut {
            button.keyboardShortcut(keyShortcut)
        } else {
            button
        }
    }
}
