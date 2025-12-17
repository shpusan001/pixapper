//
//  HelpMenuCommands.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

struct ShowShortcutsKey: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var showShortcuts: (() -> Void)? {
        get { self[ShowShortcutsKey.self] }
        set { self[ShowShortcutsKey.self] = newValue }
    }
}

struct HelpMenuCommands: Commands {
    @FocusedValue(\.showShortcuts) private var showShortcuts: (() -> Void)?

    var body: some Commands {
        CommandGroup(after: .help) {
            Button("Keyboard Shortcuts") {
                showShortcuts?()
            }
            .keyboardShortcut("?", modifiers: .command)
            .disabled(showShortcuts == nil)
        }
    }
}
