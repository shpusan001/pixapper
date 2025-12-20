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
    @State private var showingShortcutsSheet = false

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
            // Toolbar - Improved Adobe style
            HStack(spacing: 0) {
                // Left: File operations group
                HStack(spacing: 4) {
                    ToolbarTextButton(
                        icon: "doc.badge.plus",
                        text: "New",
                        tooltip: "New Project (⌘N)",
                        action: {
                            if appViewModel.isDirty {
                                showingNewProjectAlert = true
                            } else {
                                appViewModel.newProject()
                            }
                        }
                    )

                    ToolbarTextButton(
                        icon: "folder",
                        text: "Open",
                        tooltip: "Open (⌘O)",
                        action: { appViewModel.loadProject() }
                    )

                    ToolbarTextButton(
                        icon: "square.and.arrow.down",
                        text: "Save",
                        tooltip: "Save (⌘S)",
                        action: { appViewModel.saveProject() }
                    )

                    ToolbarDivider()

                    ToolbarTextButton(
                        icon: "square.and.arrow.up",
                        text: "Export",
                        tooltip: "Export (PNG, GIF, Sprite Sheet)",
                        action: { showingExportSheet = true }
                    )
                }
                .padding(.leading, 10)

                Spacer()

                // Center: Canvas size indicator
                Button(action: { showingCanvasSizeSheet = true }) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.resize")
                            .font(.system(size: 10))
                            .foregroundColor(Constants.Theme.textSecondary)
                        Text("\(canvasViewModel.canvas.width)×\(canvasViewModel.canvas.height)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("Resize Canvas (⌘R)")

                Spacer()

                // Right: Edit controls + View + Zoom
                HStack(spacing: 6) {
                    // Edit group
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

                    ToolbarDivider()

                    // View options group
                    HStack(spacing: 4) {
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

                    ToolbarDivider()

                    // Zoom control
                    HStack(spacing: 5) {
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
                        .frame(width: 90)
                        .tint(Constants.Theme.accentBlue)

                        Text("\(Int(canvasViewModel.zoomLevel))%")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Constants.Theme.textPrimary)
                            .frame(width: 40, alignment: .trailing)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 3)
                            .background(Constants.Theme.sectionBackground)
                            .cornerRadius(3)
                    }
                }
                .padding(.trailing, 10)
            }
            .frame(height: 42)
            .background(Constants.Theme.panelBackground)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Properties Panel - 가로 레이아웃 (탑 메뉴 바로 밑)
            PropertiesPanel(toolSettingsManager: toolSettingsManager, viewModel: canvasViewModel)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Main content - 좌우 분할
            HSplitView {
                // Left: Color Panel (세로 전체)
                ColorPanel(
                    colorManager: toolSettingsManager.colorManager,
                    paletteManager: timelineViewModel.pixelStateManager.paletteManager,
                    pixelStateManager: timelineViewModel.pixelStateManager,
                    commandManager: commandManager
                )
                .frame(minWidth: 140, idealWidth: 200, maxWidth: 280)

                // Center: Canvas + Timeline (상하 분할)
                VSplitView {
                    // Canvas
                    CanvasView(
                        viewModel: canvasViewModel,
                        timelineViewModel: timelineViewModel,
                        pixelStateManager: timelineViewModel.pixelStateManager
                    )
                    .frame(minWidth: 400)
                    .background(Constants.Theme.backgroundDark)

                    // Timeline
                    TimelinePanel(viewModel: timelineViewModel, commandManager: commandManager)
                        .frame(minHeight: 150, idealHeight: 250, maxHeight: 500)
                }

                // Right: Tool Panel
                ToolPanel(viewModel: canvasViewModel, toolSettingsManager: toolSettingsManager)
                    .frame(width: 48)
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
            CanvasSizeSheet(viewModel: canvasViewModel, commandManager: commandManager)
        }
        .sheet(isPresented: $showingShortcutsSheet) {
            ShortcutsView()
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
        .alert("Error", isPresented: $appViewModel.showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(appViewModel.errorMessage ?? "An unknown error occurred")
        }
        .onKeyPress { keyPress in
            // 텍스트 편집 중인지 체크
            let isTextEditing = canvasViewModel.textEditState?.isEditing ?? false

            // 모든 단축키를 ShortcutManager에서 통합 처리
            let handled = ShortcutManager.handle(
                keyPress,
                appViewModel: appViewModel,
                canvasViewModel: canvasViewModel,
                timelineViewModel: timelineViewModel,
                colorManager: appViewModel.colorManager,
                commandManager: commandManager,
                isTextEditing: isTextEditing
            )
            return handled ? .handled : .ignored
        }
        .focusedValue(\.appViewModel, appViewModel)
        .focusedValue(\.canvasViewModel, canvasViewModel)
        .focusedValue(\.timelineViewModel, timelineViewModel)
        .focusedValue(\.colorManager, appViewModel.colorManager)
        .focusedValue(\.commandManager, commandManager)
        .focusedValue(\.showShortcuts) {
            showingShortcutsSheet = true
        }
    }
}

// MARK: - Toolbar Components

struct ToolbarTextButton: View {
    let icon: String
    let text: String
    let tooltip: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(text)
                    .font(.system(size: 11))
            }
            .padding(.horizontal, Constants.Layout.Button.paddingHorizontal)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? Constants.Theme.textDisabled : Constants.Theme.textPrimary)
        .disabled(isDisabled)
        .help(tooltip)
        .hoverEffect(cornerRadius: Constants.Layout.Button.cornerRadius)
    }
}

struct ToolbarIconButton: View {
    let icon: String
    let tooltip: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .frame(width: Constants.Layout.Button.iconSize, height: Constants.Layout.Button.iconSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isDisabled ? Constants.Theme.textDisabled : Constants.Theme.textSecondary)
        .disabled(isDisabled)
        .help(tooltip)
        .hoverEffect(cornerRadius: Constants.Layout.Button.cornerRadius)
    }
}

struct ToolbarDivider: View {
    var body: some View {
        Rectangle()
            .fill(Constants.Theme.divider)
            .frame(width: 1, height: 24)
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
                .font(.system(size: 12))
                .frame(width: Constants.Layout.Button.iconSize, height: Constants.Layout.Button.iconSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(isOn ? Constants.Theme.accentBlue : Constants.Theme.textSecondary)
        .background(
            RoundedRectangle(cornerRadius: Constants.Layout.Button.cornerRadius)
                .fill(isOn ? Constants.Theme.accentBlue.opacity(0.15) : (isHovered ? Constants.Theme.hoverBackground : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Constants.Layout.Button.cornerRadius)
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
