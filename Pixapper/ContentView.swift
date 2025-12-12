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
            HStack(spacing: 12) {
                Text("Pixapper")
                    .font(.headline)

                Spacer()

                // Undo/Redo buttons
                HStack(spacing: 8) {
                    Button(action: { commandManager.undo() }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .disabled(!commandManager.canUndo)
                    .help("Undo (⌘Z)")

                    Button(action: { commandManager.redo() }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .disabled(!commandManager.canRedo)
                    .help("Redo (⌘⇧Z)")
                }
                .buttonStyle(.bordered)

                // Zoom controls
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    Slider(value: $canvasViewModel.zoomLevel, in: 100...1600, step: 100)
                        .frame(width: 120)

                    Text("\(Int(canvasViewModel.zoomLevel))%")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }

                Button(action: { showingExportSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(nsColor: .controlBackgroundColor))

            Divider()

            VSplitView {
                // Top section: Tool + Canvas + Properties
                HSplitView {
                    // Tool panel on the left
                    ToolPanel(viewModel: canvasViewModel, toolSettingsManager: toolSettingsManager)
                        .frame(minWidth: 200, idealWidth: 200, maxWidth: 320)

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

#Preview {
    ContentView()
}
