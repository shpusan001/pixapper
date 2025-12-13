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
        }
    }
}
