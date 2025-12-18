//
//  ShortcutManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//

import SwiftUI

/// 단축키 실행 관리자
/// Context-aware: 현재 상황에 따라 다른 동작 수행
@MainActor
struct ShortcutManager {

    // MARK: - Key Press Handling

    /// 키 입력을 받아서 적절한 단축키로 처리
    /// - Parameters:
    ///   - isTextEditing: 텍스트 편집 중인지 여부
    /// - Returns: 처리되었으면 true, 무시하면 false
    static func handle(
        _ keyPress: KeyPress,
        appViewModel: AppViewModel?,
        canvasViewModel: CanvasViewModel?,
        timelineViewModel: TimelineViewModel?,
        colorManager: ColorManager?,
        commandManager: CommandManager?,
        isTextEditing: Bool = false
    ) -> Bool {
        // 텍스트 편집 중이면 대부분의 단축키 무시
        if isTextEditing {
            // Escape만 허용 (텍스트 편집 취소)
            if keyPress.key == .escape {
                canvasViewModel?.cancelText()
                return true
            }

            // Cmd+Enter 허용 (텍스트 커밋)
            if keyPress.key == .return && keyPress.modifiers.contains(.command) {
                canvasViewModel?.commitText()
                return true
            }

            // 나머지는 모두 NSTextView로 전달
            return false
        }

        // KeyPress를 Shortcut으로 매핑
        guard let shortcut = mapKeyPressToShortcut(keyPress) else {
            return false
        }

        // 실행
        execute(
            shortcut,
            appViewModel: appViewModel,
            canvasViewModel: canvasViewModel,
            timelineViewModel: timelineViewModel,
            colorManager: colorManager,
            commandManager: commandManager
        )

        return true
    }

    // MARK: - Key Mapping

    /// KeyPress를 Shortcut으로 매핑
    private static func mapKeyPressToShortcut(_ keyPress: KeyPress) -> Shortcut? {
        let hasCommand = keyPress.modifiers.contains(.command)
        let hasShift = keyPress.modifiers.contains(.shift)
        let char = keyPress.characters.lowercased()

        // Special keys
        if keyPress.key == .escape {
            return .deselect
        }
        // Delete/Backspace: \u{7F} (백스페이스) 또는 deleteForward key
        if keyPress.characters == "\u{7F}" || keyPress.key == .delete || keyPress.key == .deleteForward {
            return .delete
        }
        if keyPress.key == .return {
            return .commitSelection
        }
        if keyPress.key == .space && !hasCommand {
            return .playPause
        }


        // Command + key
        if hasCommand && !hasShift {
            switch char {
            case "n": return .newProject
            case "o": return .openProject
            case "s": return .saveProject
            case "z": return .undo
            case "c": return .copy
            case "v": return .paste
            case "x": return .cut
            case "a": return .selectAll
            case "g": return .toggleGrid
            case "b": return .toggleBackground
            case "r": return .resizeCanvas
            case "+", "=": return .zoomIn
            case "-": return .zoomOut
            case "0": return .zoomReset
            default: return nil
            }
        }

        // Command + Shift + key
        if hasCommand && hasShift {
            switch char {
            case "z": return .redo
            default: return nil
            }
        }

        // Single keys (no modifier)
        if !hasCommand && !hasShift {
            switch char {
            case ",": return .previousFrame
            case ".": return .nextFrame
            case "o": return .toggleOnionSkin
            case "x": return .swapColors
            case "d": return .resetColors
            case "e": return .extendFrame
            case "k": return .convertToKeyframe
            case "b": return .addBlankKeyframe
            case "i": return .addKeyframeWithDrawing
            default: return nil
            }
        }

        return nil
    }

    // MARK: - Execution

    /// 단축키 실행
    static func execute(
        _ shortcut: Shortcut,
        appViewModel: AppViewModel?,
        canvasViewModel: CanvasViewModel?,
        timelineViewModel: TimelineViewModel?,
        colorManager: ColorManager?,
        commandManager: CommandManager?
    ) {
        switch shortcut {
        // MARK: - File
        case .newProject:
            if let app = appViewModel {
                if app.isDirty {
                    // TODO: Show alert
                    app.newProject()
                } else {
                    app.newProject()
                }
            }

        case .openProject:
            appViewModel?.loadProject()

        case .saveProject:
            appViewModel?.saveProject()

        // MARK: - Edit (Context-aware)
        case .undo:
            commandManager?.undo()

        case .redo:
            commandManager?.redo()

        case .cut:
            // Context: Selection이 있으면 Cut Selection, Frames 선택되면 Cut Frames
            if let canvas = canvasViewModel, canvas.selectionRect != nil {
                canvas.cutSelection()
            } else if let timeline = timelineViewModel, !timeline.selectedFrameIndices.isEmpty {
                executeCutFrames(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .copy:
            // Context: Selection이 있으면 Copy Selection, Frames 선택되면 Copy Frames
            if let canvas = canvasViewModel, canvas.selectionRect != nil {
                canvas.copySelection()
            } else if let timeline = timelineViewModel, !timeline.selectedFrameIndices.isEmpty {
                executeCopyFrames(timelineViewModel: timeline)
            }

        case .paste:
            // Context: Canvas clipboard이 있으면 Paste Selection, Frame clipboard이 있으면 Paste Frames
            if let canvas = canvasViewModel, canvas.hasClipboard {
                canvas.pasteSelection()
            } else if let timeline = timelineViewModel, !timeline.frameClipboard.isEmpty {
                executePasteFrames(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .delete:
            // Context: Selection이 있으면 Delete Selection, Frames 선택되면 Delete Frames
            if let canvas = canvasViewModel, canvas.selectionRect != nil {
                canvas.deleteSelection()
            } else if let timeline = timelineViewModel, !timeline.selectedFrameIndices.isEmpty {
                executeDeleteFrames(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .selectAll:
            // TODO: Implement selectAll
            break

        case .deselect:
            canvasViewModel?.cancelSelection()

        // MARK: - View
        case .toggleGrid:
            canvasViewModel?.toggleGrid()

        case .toggleBackground:
            canvasViewModel?.toggleBackground()

        case .resizeCanvas:
            // TODO: Show sheet (handled in ContentView)
            break

        case .zoomIn:
            if let canvas = canvasViewModel {
                canvas.zoomLevel = min(canvas.zoomLevel + 100, 1600)
            }

        case .zoomOut:
            if let canvas = canvasViewModel {
                canvas.zoomLevel = max(canvas.zoomLevel - 100, 100)
            }

        case .zoomReset:
            canvasViewModel?.zoomLevel = 400

        // MARK: - Timeline
        case .playPause:
            timelineViewModel?.togglePlayback()

        case .nextFrame:
            timelineViewModel?.nextFrame()

        case .previousFrame:
            timelineViewModel?.previousFrame()

        case .toggleOnionSkin:
            timelineViewModel?.toggleOnionSkin()

        case .copyFrames:
            if let timeline = timelineViewModel {
                executeCopyFrames(timelineViewModel: timeline)
            }

        case .pasteFrames:
            if let timeline = timelineViewModel {
                executePasteFrames(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .cutFrames:
            if let timeline = timelineViewModel {
                executeCutFrames(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .deleteFrames:
            if let timeline = timelineViewModel {
                executeDeleteFrames(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .extendFrame:
            if let timeline = timelineViewModel {
                executeExtendFrame(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .convertToKeyframe:
            if let timeline = timelineViewModel {
                executeConvertToKeyframe(timelineViewModel: timeline)
            }

        case .addBlankKeyframe:
            if let timeline = timelineViewModel {
                executeAddBlankKeyframe(timelineViewModel: timeline, commandManager: commandManager)
            }

        case .addKeyframeWithDrawing:
            if let timeline = timelineViewModel {
                executeAddKeyframeWithDrawing(timelineViewModel: timeline, commandManager: commandManager)
            }

        // MARK: - Color
        case .swapColors:
            colorManager?.swapColors()

        case .resetColors:
            colorManager?.resetToDefaults()

        // MARK: - Selection
        case .commitSelection:
            if canvasViewModel?.isFloatingSelection == true {
                canvasViewModel?.commitSelection()
            }

        case .cancelSelection:
            canvasViewModel?.cancelSelection()
        }
    }

    // MARK: - Availability Check

    /// 단축키가 현재 실행 가능한지 체크
    static func canExecute(
        _ shortcut: Shortcut,
        appViewModel: AppViewModel?,
        canvasViewModel: CanvasViewModel?,
        timelineViewModel: TimelineViewModel?,
        colorManager: ColorManager?,
        commandManager: CommandManager?
    ) -> Bool {
        switch shortcut {
        // File - 항상 가능
        case .newProject, .openProject, .saveProject:
            return appViewModel != nil

        // Edit
        case .undo:
            return commandManager?.canUndo ?? false

        case .redo:
            return commandManager?.canRedo ?? false

        case .cut:
            // 항상 활성화 (잘라낼 게 없으면 그냥 무시)
            return true

        case .copy:
            // 항상 활성화 (복사할 게 없으면 그냥 무시)
            return true

        case .paste:
            // 항상 활성화 (붙여넣을 게 없으면 그냥 무시)
            return true

        case .delete:
            // 항상 활성화 (삭제할 게 없으면 그냥 무시)
            return true

        case .selectAll:
            return canvasViewModel != nil

        case .deselect:
            // 항상 활성화 (selection 없어도 Esc 누를 수 있어야 함)
            return true

        // View
        case .toggleGrid, .toggleBackground:
            return canvasViewModel != nil

        case .resizeCanvas:
            return canvasViewModel != nil

        case .zoomIn:
            return (canvasViewModel?.zoomLevel ?? 1600) < 1600

        case .zoomOut:
            return (canvasViewModel?.zoomLevel ?? 100) > 100

        case .zoomReset:
            return canvasViewModel != nil

        // Timeline
        case .playPause, .nextFrame, .previousFrame, .toggleOnionSkin:
            return timelineViewModel != nil

        case .copyFrames, .cutFrames, .deleteFrames:
            // 항상 활성화 (선택된 프레임 없으면 그냥 무시)
            return true

        case .pasteFrames:
            // 항상 활성화 (클립보드 비어있으면 그냥 무시)
            return true

        case .extendFrame, .convertToKeyframe, .addBlankKeyframe, .addKeyframeWithDrawing:
            return timelineViewModel != nil

        // Color
        case .swapColors, .resetColors:
            return colorManager != nil

        // Selection
        case .commitSelection:
            // 항상 활성화 (floating selection 아니면 그냥 무시)
            return true

        case .cancelSelection:
            // 항상 활성화 (selection 없어도 Esc 누를 수 있어야 함)
            return true
        }
    }

    // MARK: - Private Helpers

    private static func executeCopyFrames(timelineViewModel: TimelineViewModel) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        timelineViewModel.copyFrames(frameIndices: timelineViewModel.selectedFrameIndices, layerId: layerId)
    }

    private static func executePasteFrames(timelineViewModel: TimelineViewModel, commandManager: CommandManager?) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        let command = PasteFramesCommand(
            timelineViewModel: timelineViewModel,
            startIndex: timelineViewModel.currentFrameIndex,
            layerId: layerId
        )
        commandManager?.performCommand(command)
    }

    private static func executeCutFrames(timelineViewModel: TimelineViewModel, commandManager: CommandManager?) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        let command = CutFramesCommand(
            timelineViewModel: timelineViewModel,
            frameIndices: timelineViewModel.selectedFrameIndices,
            layerId: layerId
        )
        commandManager?.performCommand(command)
    }

    private static func executeDeleteFrames(timelineViewModel: TimelineViewModel, commandManager: CommandManager?) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        let command = DeleteFramesCommand(
            timelineViewModel: timelineViewModel,
            frameIndices: timelineViewModel.selectedFrameIndices,
            layerId: layerId
        )
        commandManager?.performCommand(command)
    }

    private static func executeExtendFrame(timelineViewModel: TimelineViewModel, commandManager: CommandManager?) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        let command = ExtendFrameCommand(
            timelineViewModel: timelineViewModel,
            frameIndex: timelineViewModel.currentFrameIndex,
            layerId: layerId
        )
        commandManager?.performCommand(command)
    }

    private static func executeConvertToKeyframe(timelineViewModel: TimelineViewModel) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        timelineViewModel.toggleKeyframe(frameIndex: timelineViewModel.currentFrameIndex, layerId: layerId)
    }

    private static func executeAddBlankKeyframe(timelineViewModel: TimelineViewModel, commandManager: CommandManager?) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        let command = AddBlankKeyframeCommand(
            timelineViewModel: timelineViewModel,
            layerId: layerId,
            canvasWidth: timelineViewModel.canvasWidth,
            canvasHeight: timelineViewModel.canvasHeight
        )
        commandManager?.performCommand(command)
    }

    private static func executeAddKeyframeWithDrawing(timelineViewModel: TimelineViewModel, commandManager: CommandManager?) {
        guard let layerId = timelineViewModel.layerViewModel.layers[safe: timelineViewModel.layerViewModel.selectedLayerIndex]?.id else { return }
        let command = AddKeyframeWithContentCommand(
            timelineViewModel: timelineViewModel,
            layerId: layerId
        )
        commandManager?.performCommand(command)
    }
}

// MARK: - Array Safe Subscript

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
