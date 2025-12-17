//
//  FileMenuCommands.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

struct FileMenuCommands: Commands {
    @FocusedValue(\.appViewModel) private var appViewModel: AppViewModel?
    @FocusedValue(\.canvasViewModel) private var canvasViewModel: CanvasViewModel?
    @FocusedValue(\.timelineViewModel) private var timelineViewModel: TimelineViewModel?
    @FocusedValue(\.colorManager) private var colorManager: ColorManager?
    @FocusedValue(\.commandManager) private var commandManager: CommandManager?

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            shortcutButton(.newProject)
            shortcutButton(.openProject)
            Divider()
            shortcutButton(.saveProject)
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
