//
//  PixapperApp.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

@main
struct PixapperApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            EditCommands()
        }
    }
}

// MARK: - Custom Commands
struct EditCommands: Commands {
    @FocusedValue(\.canvasViewModel) private var canvasViewModel: CanvasViewModel?

    var body: some Commands {
        // Undo/Redo 커맨드
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                canvasViewModel?.performUndo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!(canvasViewModel?.commandManager.canUndo ?? false))

            Button("Redo") {
                canvasViewModel?.performRedo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!(canvasViewModel?.commandManager.canRedo ?? false))
        }

        CommandGroup(replacing: .pasteboard) {
            Button("Cut") {
                canvasViewModel?.cutSelection()
            }
            .keyboardShortcut("x", modifiers: .command)
            .disabled(canvasViewModel?.selectionRect == nil)

            Button("Copy") {
                canvasViewModel?.copySelection()
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(canvasViewModel?.selectionRect == nil)

            Button("Paste") {
                canvasViewModel?.pasteSelection()
            }
            .keyboardShortcut("v", modifiers: .command)
            .disabled(!(canvasViewModel?.hasClipboard ?? false))

            Divider()

            Button("Delete") {
                canvasViewModel?.deleteSelection()
            }
            .keyboardShortcut(.delete)
            .disabled(canvasViewModel?.selectionRect == nil)

            Button("Delete (Backspace)") {
                canvasViewModel?.deleteSelection()
            }
            .keyboardShortcut(.deleteForward)
            .disabled(canvasViewModel?.selectionRect == nil)

            Divider()

            Button("Commit Selection") {
                if canvasViewModel?.isFloatingSelection == true {
                    canvasViewModel?.commitSelection()
                }
            }
            .keyboardShortcut(.return)
            .disabled(canvasViewModel?.isFloatingSelection != true)

            Button("Deselect") {
                canvasViewModel?.clearSelection()
            }
            .keyboardShortcut(.escape)
            .disabled(canvasViewModel?.selectionRect == nil)
        }
    }
}
