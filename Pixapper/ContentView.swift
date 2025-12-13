//
//  ContentView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var layerViewModel = LayerViewModel(
        width: Constants.Canvas.defaultWidth,
        height: Constants.Canvas.defaultHeight
    )
    @StateObject private var commandManager = CommandManager()
    @StateObject private var toolSettingsManager = ToolSettingsManager()
    @StateObject private var canvasViewModel: CanvasViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @FocusState private var isFocused: Bool
    @State private var showingExportSheet = false
    @State private var showingCanvasSizeSheet = false

    init() {
        // 의존성 그래프 (Dependency Graph):
        // LayerViewModel (공유) ← CanvasViewModel, TimelineViewModel
        // CommandManager (공유) ← CanvasViewModel, TimelinePanel
        // ToolSettingsManager ← CanvasViewModel
        // TimelineViewModel → CanvasViewModel (weak 참조로 역방향 통신)

        let layerVM = LayerViewModel(
            width: Constants.Canvas.defaultWidth,
            height: Constants.Canvas.defaultHeight
        )
        let cmdManager = CommandManager()
        let toolManager = ToolSettingsManager()

        // CanvasViewModel: 그리기 작업과 레이어 픽셀 관리
        let canvasVM = CanvasViewModel(
            width: Constants.Canvas.defaultWidth,
            height: Constants.Canvas.defaultHeight,
            layerViewModel: layerVM,
            commandManager: cmdManager,
            toolSettingsManager: toolManager
        )

        // TimelineViewModel: 프레임/키프레임 관리
        let timelineVM = TimelineViewModel(
            width: Constants.Canvas.defaultWidth,
            height: Constants.Canvas.defaultHeight,
            layerViewModel: layerVM
        )

        // SwiftUI @StateObject 래핑
        _layerViewModel = StateObject(wrappedValue: layerVM)
        _commandManager = StateObject(wrappedValue: cmdManager)
        _toolSettingsManager = StateObject(wrappedValue: toolManager)
        _canvasViewModel = StateObject(wrappedValue: canvasVM)
        _timelineViewModel = StateObject(wrappedValue: timelineVM)

        // Canvas → Timeline 역방향 통신 연결 (weak 참조로 순환 참조 방지)
        // 그리기 작업 완료 시 Timeline에 동기화하기 위함
        canvasVM.timelineViewModel = timelineVM

        // 초기 프레임 로드 (Frame 0의 키프레임 데이터를 각 레이어에 로드)
        timelineVM.loadFrame(at: 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 0) {
                // App title
                Text("Pixapper")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.leading, 16)

                Spacer()

                // Left group: Undo/Redo
                HStack(spacing: 4) {
                    ToolbarIconButton(
                        icon: "arrow.uturn.backward",
                        tooltip: "Undo (⌘Z)",
                        isDisabled: !commandManager.canUndo,
                        action: { commandManager.undo() }
                    )

                    ToolbarIconButton(
                        icon: "arrow.uturn.forward",
                        tooltip: "Redo (⌘⇧Z)",
                        isDisabled: !commandManager.canRedo,
                        action: { commandManager.redo() }
                    )
                }
                .padding(.trailing, 8)

                ToolbarDivider()

                // Center group: Zoom controls
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Slider(value: $canvasViewModel.zoomLevel, in: 100...1600, step: 100)
                        .frame(width: 100)

                    Text("\(Int(canvasViewModel.zoomLevel))%")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(width: 45, alignment: .trailing)
                }
                .padding(.horizontal, 8)

                ToolbarDivider()

                // Right group: Canvas size & Export
                HStack(spacing: 4) {
                    ToolbarIconButton(
                        icon: "aspectratio",
                        tooltip: "Resize Canvas",
                        action: { showingCanvasSizeSheet = true }
                    )

                    Button(action: { showingCanvasSizeSheet = true }) {
                        Text("\(canvasViewModel.canvas.width)×\(canvasViewModel.canvas.height)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Resize Canvas")

                    ToolbarIconButton(
                        icon: "square.and.arrow.up",
                        tooltip: "Export",
                        action: { showingExportSheet = true }
                    )
                }
                .padding(.trailing, 16)
            }
            .frame(height: 40)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.95))

            Divider()

            VSplitView {
                // Top section: Tool + Canvas + Properties
                HSplitView {
                    // Tool panel on the left
                    ToolPanel(viewModel: canvasViewModel, toolSettingsManager: toolSettingsManager)
                        .frame(minWidth: 52, idealWidth: 52, maxWidth: 80)

                    // Canvas in the center
                    CanvasView(viewModel: canvasViewModel, timelineViewModel: timelineViewModel)
                        .frame(minWidth: 400)

                    // Properties panel on the right
                    PropertiesPanel(toolSettingsManager: toolSettingsManager, viewModel: canvasViewModel)
                        .frame(minWidth: 200, idealWidth: 200, maxWidth: 320)
                }

                // Timeline panel at the bottom
                TimelinePanel(viewModel: timelineViewModel, commandManager: commandManager)
                    .frame(minHeight: 150, idealHeight: 280, maxHeight: 600)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingExportSheet) {
            ExportView(
                timelineViewModel: timelineViewModel,
                canvasWidth: canvasViewModel.canvas.width,
                canvasHeight: canvasViewModel.canvas.height
            )
        }
        .sheet(isPresented: $showingCanvasSizeSheet) {
            CanvasSizeSheet(viewModel: canvasViewModel)
        }
        .focusable()
        .focused($isFocused)
        .onAppear {
            isFocused = true
        }
        .onKeyPress { keyPress in
            // Undo (Cmd+Z)
            if keyPress.characters == "z" && keyPress.modifiers.contains(.command) && !keyPress.modifiers.contains(.shift) {
                if commandManager.canUndo {
                    commandManager.undo()
                }
                return .handled
            }
            // Redo (Cmd+Shift+Z)
            else if keyPress.characters == "Z" && keyPress.modifiers.contains(.command) {
                if commandManager.canRedo {
                    commandManager.redo()
                }
                return .handled
            }
            // Copy (Cmd+C)
            else if keyPress.characters == "c" && keyPress.modifiers.contains(.command) {
                canvasViewModel.copySelection()
                return .handled
            }
            // Cut (Cmd+X)
            else if keyPress.characters == "x" && keyPress.modifiers.contains(.command) {
                canvasViewModel.cutSelection()
                return .handled
            }
            // Paste (Cmd+V)
            else if keyPress.characters == "v" && keyPress.modifiers.contains(.command) {
                canvasViewModel.pasteSelection()
                return .handled
            }
            // Delete selection (Delete/Backspace)
            else if keyPress.key == .delete || keyPress.key == .deleteForward {
                canvasViewModel.deleteSelection()
                return .handled
            }
            // Commit selection (Enter/Return)
            else if keyPress.key == .return {
                if canvasViewModel.isFloatingSelection {
                    canvasViewModel.commitSelection()
                }
                return .handled
            }
            // Cancel selection (Escape)
            else if keyPress.key == .escape {
                if canvasViewModel.selectionRect != nil {
                    canvasViewModel.clearSelection()
                }
                return .handled
            }
            // Timeline controls
            else if keyPress.characters == " " {
                timelineViewModel.togglePlayback()
                return .handled
            } else if keyPress.characters == "," {
                timelineViewModel.previousFrame()
                return .handled
            } else if keyPress.characters == "." {
                timelineViewModel.nextFrame()
                return .handled
            } else if keyPress.characters == "o" || keyPress.characters == "O" {
                timelineViewModel.toggleOnionSkin()
                return .handled
            }
            return .ignored
        }
    }
}

// MARK: - Toolbar Components

struct ToolbarIconButton: View {
    let icon: String
    let tooltip: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? .secondary.opacity(0.5) : .secondary)
        .disabled(isDisabled)
        .help(tooltip)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color.clear, lineWidth: 0)
        )
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.2))
            .frame(width: 1, height: 20)
            .padding(.horizontal, 8)
    }
}

#Preview {
    ContentView()
}
