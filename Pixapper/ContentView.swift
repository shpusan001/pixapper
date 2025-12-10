//
//  ContentView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var layerViewModel = LayerViewModel(width: 32, height: 32)
    @StateObject private var commandManager = CommandManager()
    @StateObject private var toolSettingsManager = ToolSettingsManager()
    @StateObject private var canvasViewModel: CanvasViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @FocusState private var isFocused: Bool
    @State private var showingExportSheet = false

    init() {
        let layerVM = LayerViewModel(width: 32, height: 32)
        let cmdManager = CommandManager()
        let toolManager = ToolSettingsManager()

        _layerViewModel = StateObject(wrappedValue: layerVM)
        _commandManager = StateObject(wrappedValue: cmdManager)
        _toolSettingsManager = StateObject(wrappedValue: toolManager)
        _canvasViewModel = StateObject(wrappedValue: CanvasViewModel(width: 32, height: 32, layerViewModel: layerVM, commandManager: cmdManager, toolSettingsManager: toolManager))
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel(width: 32, height: 32, layerViewModel: layerVM))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
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

                Spacer().frame(width: 12)

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

            VStack(spacing: 0) {
            HStack(spacing: 0) {
                // Tool panel on the left
                ToolPanel(viewModel: canvasViewModel, toolSettingsManager: toolSettingsManager)

                Divider()

                // Canvas in the center
                CanvasView(viewModel: canvasViewModel, timelineViewModel: timelineViewModel)

                Divider()

                // Layer panel on the right
                LayerPanel(viewModel: layerViewModel)
            }

            // Timeline panel at the bottom
            TimelinePanel(viewModel: timelineViewModel)
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
