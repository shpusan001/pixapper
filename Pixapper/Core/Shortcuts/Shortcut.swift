//
//  Shortcut.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

/// 앱의 모든 단축키 정의
/// 한 곳에서 중앙 집중 관리
enum Shortcut: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    // MARK: - File
    case newProject
    case openProject
    case saveProject

    // MARK: - Edit
    case undo
    case redo
    case cut
    case copy
    case paste
    case delete
    case selectAll
    case deselect

    // MARK: - View
    case toggleGrid
    case toggleBackground
    case resizeCanvas
    case zoomIn
    case zoomOut
    case zoomReset

    // MARK: - Timeline
    case playPause
    case nextFrame
    case previousFrame
    case toggleOnionSkin
    case copyFrames
    case pasteFrames
    case cutFrames
    case deleteFrames

    // MARK: - Color
    case swapColors
    case resetColors

    // MARK: - Selection
    case commitSelection
    case cancelSelection

    // MARK: - Properties

    /// 카테고리
    var category: ShortcutCategory {
        switch self {
        case .newProject, .openProject, .saveProject:
            return .file
        case .undo, .redo, .cut, .copy, .paste, .delete, .selectAll, .deselect:
            return .edit
        case .toggleGrid, .toggleBackground, .resizeCanvas, .zoomIn, .zoomOut, .zoomReset:
            return .view
        case .playPause, .nextFrame, .previousFrame, .toggleOnionSkin,
             .copyFrames, .pasteFrames, .cutFrames, .deleteFrames:
            return .timeline
        case .swapColors, .resetColors:
            return .color
        case .commitSelection, .cancelSelection:
            return .selection
        }
    }

    /// 메뉴에 표시될 이름
    var menuTitle: String {
        switch self {
        case .newProject: return "New Project"
        case .openProject: return "Open..."
        case .saveProject: return "Save"

        case .undo: return "Undo"
        case .redo: return "Redo"
        case .cut: return "Cut"
        case .copy: return "Copy"
        case .paste: return "Paste"
        case .delete: return "Delete"
        case .selectAll: return "Select All"
        case .deselect: return "Deselect"

        case .toggleGrid: return "Toggle Grid"
        case .toggleBackground: return "Toggle Background"
        case .resizeCanvas: return "Resize Canvas..."
        case .zoomIn: return "Zoom In"
        case .zoomOut: return "Zoom Out"
        case .zoomReset: return "Actual Size"

        case .playPause: return "Play/Pause"
        case .nextFrame: return "Next Frame"
        case .previousFrame: return "Previous Frame"
        case .toggleOnionSkin: return "Toggle Onion Skin"
        case .copyFrames: return "Copy Frames"
        case .pasteFrames: return "Paste Frames"
        case .cutFrames: return "Cut Frames"
        case .deleteFrames: return "Delete Frames"

        case .swapColors: return "Swap Foreground/Background"
        case .resetColors: return "Reset to Default Colors"

        case .commitSelection: return "Commit Selection"
        case .cancelSelection: return "Cancel Selection"
        }
    }

    /// 기본 키보드 단축키
    var defaultKeyboardShortcut: KeyboardShortcut? {
        switch self {
        // File
        case .newProject:
            return KeyboardShortcut("n", modifiers: .command)
        case .openProject:
            return KeyboardShortcut("o", modifiers: .command)
        case .saveProject:
            return KeyboardShortcut("s", modifiers: .command)

        // Edit
        case .undo:
            return KeyboardShortcut("z", modifiers: .command)
        case .redo:
            return KeyboardShortcut("z", modifiers: [.command, .shift])
        case .cut:
            return KeyboardShortcut("x", modifiers: .command)
        case .copy:
            return KeyboardShortcut("c", modifiers: .command)
        case .paste:
            return KeyboardShortcut("v", modifiers: .command)
        case .delete:
            return KeyboardShortcut(.delete)
        case .selectAll:
            return KeyboardShortcut("a", modifiers: .command)
        case .deselect:
            return KeyboardShortcut(.escape)

        // View
        case .toggleGrid:
            return KeyboardShortcut("g", modifiers: .command)
        case .toggleBackground:
            return KeyboardShortcut("b", modifiers: .command)
        case .resizeCanvas:
            return KeyboardShortcut("r", modifiers: .command)
        case .zoomIn:
            return KeyboardShortcut("+", modifiers: .command)
        case .zoomOut:
            return KeyboardShortcut("-", modifiers: .command)
        case .zoomReset:
            return KeyboardShortcut("0", modifiers: .command)

        // Timeline
        case .playPause:
            return KeyboardShortcut(.space)
        case .nextFrame:
            return KeyboardShortcut(".")
        case .previousFrame:
            return KeyboardShortcut(",")
        case .toggleOnionSkin:
            return KeyboardShortcut("o")
        case .copyFrames:
            return nil  // Context-dependent, uses .copy
        case .pasteFrames:
            return nil  // Context-dependent, uses .paste
        case .cutFrames:
            return nil  // Context-dependent, uses .cut
        case .deleteFrames:
            return nil  // Context-dependent, uses .delete

        // Color
        case .swapColors:
            return KeyboardShortcut("x")
        case .resetColors:
            return KeyboardShortcut("d")

        // Selection
        case .commitSelection:
            return KeyboardShortcut(.return)
        case .cancelSelection:
            return nil  // Same as deselect
        }
    }

    /// 단축키를 사람이 읽을 수 있는 문자열로 표시
    /// 예: ⌘N, ⌘⇧Z, Space
    var shortcutDisplayString: String {
        switch self {
        // File
        case .newProject: return "⌘N"
        case .openProject: return "⌘O"
        case .saveProject: return "⌘S"

        // Edit
        case .undo: return "⌘Z"
        case .redo: return "⌘⇧Z"
        case .cut: return "⌘X"
        case .copy: return "⌘C"
        case .paste: return "⌘V"
        case .delete: return "⌫"
        case .selectAll: return "⌘A"
        case .deselect: return "Esc"

        // View
        case .toggleGrid: return "⌘G"
        case .toggleBackground: return "⌘B"
        case .resizeCanvas: return "⌘R"
        case .zoomIn: return "⌘+"
        case .zoomOut: return "⌘-"
        case .zoomReset: return "⌘0"

        // Timeline
        case .playPause: return "Space"
        case .nextFrame: return "."
        case .previousFrame: return ","
        case .toggleOnionSkin: return "O"
        case .copyFrames: return "⌘C"
        case .pasteFrames: return "⌘V"
        case .cutFrames: return "⌘X"
        case .deleteFrames: return "⌫"

        // Color
        case .swapColors: return "X"
        case .resetColors: return "D"

        // Selection
        case .commitSelection: return "↵"
        case .cancelSelection: return "Esc"
        }
    }

    /// 단축키 설명 (툴팁, Preferences용)
    var description: String {
        switch self {
        case .newProject: return "Create a new project"
        case .openProject: return "Open an existing project"
        case .saveProject: return "Save the current project"

        case .undo: return "Undo the last action"
        case .redo: return "Redo the last undone action"
        case .cut: return "Cut selection to clipboard"
        case .copy: return "Copy selection to clipboard"
        case .paste: return "Paste from clipboard"
        case .delete: return "Delete selection"
        case .selectAll: return "Select entire canvas"
        case .deselect: return "Clear selection"

        case .toggleGrid: return "Show or hide pixel grid"
        case .toggleBackground: return "Toggle between checkerboard and solid background"
        case .resizeCanvas: return "Change canvas dimensions"
        case .zoomIn: return "Zoom in"
        case .zoomOut: return "Zoom out"
        case .zoomReset: return "Reset zoom to 100%"

        case .playPause: return "Play or pause animation"
        case .nextFrame: return "Go to next frame"
        case .previousFrame: return "Go to previous frame"
        case .toggleOnionSkin: return "Show or hide onion skin"
        case .copyFrames: return "Copy selected frames"
        case .pasteFrames: return "Paste copied frames"
        case .cutFrames: return "Cut selected frames"
        case .deleteFrames: return "Delete selected frames"

        case .swapColors: return "Swap primary and secondary colors"
        case .resetColors: return "Reset colors to black and white"

        case .commitSelection: return "Apply floating selection"
        case .cancelSelection: return "Cancel current selection"
        }
    }
}

/// 단축키 카테고리
enum ShortcutCategory: String, CaseIterable {
    case file = "File"
    case edit = "Edit"
    case view = "View"
    case timeline = "Timeline"
    case color = "Color"
    case selection = "Selection"

    var displayName: String {
        rawValue
    }

    /// 카테고리에 속한 모든 단축키
    var shortcuts: [Shortcut] {
        Shortcut.allCases.filter { $0.category == self }
    }
}
