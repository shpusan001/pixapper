//
//  ContentView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

// MARK: - FocusedValues for menu commands
struct CanvasViewModelKey: FocusedValueKey {
    typealias Value = CanvasViewModel
}

extension FocusedValues {
    var canvasViewModel: CanvasViewModel? {
        get { self[CanvasViewModelKey.self] }
        set { self[CanvasViewModelKey.self] = newValue }
    }
}

struct ContentView: View {
    @StateObject private var appViewModel = AppViewModel(
        width: Constants.Canvas.defaultWidth,
        height: Constants.Canvas.defaultHeight
    )
    @FocusState private var isFocused: Bool
    @State private var showingExportSheet = false
    @State private var showingCanvasSizeSheet = false
    @State private var showingNewProjectAlert = false

    // Convenience accessors
    private var layerViewModel: LayerViewModel { appViewModel.layerViewModel }
    private var commandManager: CommandManager { appViewModel.commandManager }
    private var toolSettingsManager: ToolSettingsManager { appViewModel.toolSettingsManager }
    private var timelineViewModel: TimelineViewModel { appViewModel.timelineViewModel }

    // Direct observation for immediate UI updates
    @ObservedObject private var canvasViewModel: CanvasViewModel

    init() {
        let app = AppViewModel(
            width: Constants.Canvas.defaultWidth,
            height: Constants.Canvas.defaultHeight
        )
        _appViewModel = StateObject(wrappedValue: app)
        _canvasViewModel = ObservedObject(wrappedValue: app.canvasViewModel)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar - Adobe style with better grouping
            HStack(spacing: 0) {
                // Left: File operations group
                HStack(spacing: 8) {
                    ToolbarIconButton(
                        icon: "doc.badge.plus",
                        tooltip: "New Project (⌘N)",
                        action: {
                            if appViewModel.isDirty {
                                showingNewProjectAlert = true
                            } else {
                                appViewModel.newProject()
                            }
                        }
                    )

                    ToolbarIconButton(
                        icon: "folder",
                        tooltip: "Open (⌘O)",
                        action: { appViewModel.loadProject() }
                    )

                    ToolbarIconButton(
                        icon: "square.and.arrow.down",
                        tooltip: "Save (⌘S)",
                        action: { appViewModel.saveProject() }
                    )

                    ToolbarDivider()

                    ToolbarIconButton(
                        icon: "square.and.arrow.up",
                        tooltip: "Export (PNG, GIF, Sprite Sheet)",
                        action: { showingExportSheet = true }
                    )
                }
                .padding(.leading, 12)

                Spacer()

                // Center: Canvas info and controls
                HStack(spacing: 12) {
                    // Canvas size indicator (clickable)
                    Button(action: { showingCanvasSizeSheet = true }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.resize")
                                .font(.system(size: 10))
                            Text("\(canvasViewModel.canvas.width)×\(canvasViewModel.canvas.height)")
                                .font(.system(size: 10, design: .monospaced))
                        }
                        .foregroundColor(Constants.Theme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Constants.Theme.sectionBackground)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Resize Canvas (⌘R)")

                    // Zoom control
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Theme.textSecondary)

                        Slider(
                            value: Binding(
                                get: { appViewModel.canvasViewModel.zoomLevel },
                                set: { appViewModel.canvasViewModel.zoomLevel = $0 }
                            ),
                            in: 100...1600,
                            step: 100
                        )
                        .frame(width: 100)
                        .tint(Constants.Theme.accentBlue)

                        Text("\(Int(canvasViewModel.zoomLevel))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                            .frame(width: 42, alignment: .center)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Constants.Theme.sectionBackground)
                            .cornerRadius(2)
                    }
                }

                Spacer()

                // Right: View and Edit controls
                HStack(spacing: 8) {
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

                    ToolbarDivider()

                    ToolbarIconButton(
                        icon: canvasViewModel.backgroundMode == .checkerboard ? "checkerboard.rectangle" : "rectangle.fill",
                        tooltip: canvasViewModel.backgroundMode == .checkerboard ? "White Background (⌘B)" : "Checkerboard (⌘B)",
                        action: { canvasViewModel.toggleBackground() }
                    )

                    ToolbarToggleButton(
                        icon: "grid",
                        tooltip: "Toggle Grid (⌘G)",
                        isOn: canvasViewModel.showGrid,
                        action: { canvasViewModel.toggleGrid() }
                    )
                }
                .padding(.trailing, 12)
            }
            .frame(height: 36)
            .background(Constants.Theme.panelBackground)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            VSplitView {
                // Top section: Tool + Canvas + Properties
                HSplitView {
                    // Tool panel on the left (fixed width)
                    ToolPanel(viewModel: canvasViewModel, toolSettingsManager: toolSettingsManager)
                        .frame(width: 50)

                    // Canvas in the center
                    CanvasView(viewModel: canvasViewModel, timelineViewModel: timelineViewModel)
                        .frame(minWidth: 400)
                        .background(Constants.Theme.backgroundDark)

                    // Properties panel on the right
                    PropertiesPanel(toolSettingsManager: toolSettingsManager, viewModel: canvasViewModel)
                        .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)
                }

                // Timeline panel at the bottom
                TimelinePanel(viewModel: timelineViewModel, commandManager: commandManager)
                    .frame(minHeight: 150, idealHeight: 250, maxHeight: 500)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Constants.Theme.backgroundDark)
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
        .alert("Unsaved Changes", isPresented: $showingNewProjectAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Discard", role: .destructive) {
                appViewModel.newProject()
            }
            Button("Save") {
                if appViewModel.saveProject() {
                    appViewModel.newProject()
                }
            }
        } message: {
            Text("You have unsaved changes. Do you want to save before creating a new project?")
        }
        .onKeyPress { keyPress in
            // New Project (Cmd+N)
            if keyPress.characters == "n" && keyPress.modifiers.contains(.command) {
                if appViewModel.isDirty {
                    showingNewProjectAlert = true
                } else {
                    appViewModel.newProject()
                }
                return .handled
            }
            // Open (Cmd+O)
            else if keyPress.characters == "o" && keyPress.modifiers.contains(.command) {
                appViewModel.loadProject()
                return .handled
            }
            // Save (Cmd+S)
            else if keyPress.characters == "s" && keyPress.modifiers.contains(.command) {
                appViewModel.saveProject()
                return .handled
            }
            // Resize Canvas (Cmd+R)
            else if keyPress.characters == "r" && keyPress.modifiers.contains(.command) {
                showingCanvasSizeSheet = true
                return .handled
            }
            // Toggle Background (Cmd+B)
            else if keyPress.characters == "b" && keyPress.modifiers.contains(.command) {
                canvasViewModel.toggleBackground()
                return .handled
            }
            // Toggle Grid (Cmd+G)
            else if keyPress.characters == "g" && keyPress.modifiers.contains(.command) {
                canvasViewModel.toggleGrid()
                return .handled
            }
            // Undo (Cmd+Z)
            else if keyPress.characters == "z" && keyPress.modifiers.contains(.command) && !keyPress.modifiers.contains(.shift) {
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
        .focusedValue(\.canvasViewModel, canvasViewModel)
    }
}

// MARK: - Toolbar Components

struct ToolbarIconButton: View {
    let icon: String
    let tooltip: String
    var isDisabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? Constants.Theme.textDisabled : Constants.Theme.textSecondary)
        .disabled(isDisabled)
        .help(tooltip)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(isHovered && !isDisabled ? Constants.Theme.hoverBackground : Color.clear)
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Constants.Theme.divider)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 6)
    }
}

struct ToolbarToggleButton: View {
    let icon: String
    let tooltip: String
    let isOn: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isOn ? Constants.Theme.accentBlue : Constants.Theme.textSecondary)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(isOn ? Constants.Theme.accentBlue.opacity(0.15) : (isHovered ? Constants.Theme.hoverBackground : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(isOn ? Constants.Theme.accentBlue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    ContentView()
}
