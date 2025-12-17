//
//  FocusedValues+App.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

// MARK: - AppViewModel

struct AppViewModelKey: FocusedValueKey {
    typealias Value = AppViewModel
}

extension FocusedValues {
    var appViewModel: AppViewModel? {
        get { self[AppViewModelKey.self] }
        set { self[AppViewModelKey.self] = newValue }
    }
}

// MARK: - TimelineViewModel

struct TimelineViewModelKey: FocusedValueKey {
    typealias Value = TimelineViewModel
}

extension FocusedValues {
    var timelineViewModel: TimelineViewModel? {
        get { self[TimelineViewModelKey.self] }
        set { self[TimelineViewModelKey.self] = newValue }
    }
}

// MARK: - ColorManager

struct ColorManagerKey: FocusedValueKey {
    typealias Value = ColorManager
}

extension FocusedValues {
    var colorManager: ColorManager? {
        get { self[ColorManagerKey.self] }
        set { self[ColorManagerKey.self] = newValue }
    }
}

// MARK: - CommandManager

struct CommandManagerKey: FocusedValueKey {
    typealias Value = CommandManager
}

extension FocusedValues {
    var commandManager: CommandManager? {
        get { self[CommandManagerKey.self] }
        set { self[CommandManagerKey.self] = newValue }
    }
}
