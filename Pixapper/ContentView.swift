//
//  ContentView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var layerViewModel = LayerViewModel(width: 32, height: 32)
    @StateObject private var canvasViewModel: CanvasViewModel
    @StateObject private var timelineViewModel: TimelineViewModel
    @FocusState private var isFocused: Bool
    @State private var showingExportSheet = false

    init() {
        let layerVM = LayerViewModel(width: 32, height: 32)
        _layerViewModel = StateObject(wrappedValue: layerVM)
        _canvasViewModel = StateObject(wrappedValue: CanvasViewModel(width: 32, height: 32, layerViewModel: layerVM))
        _timelineViewModel = StateObject(wrappedValue: TimelineViewModel(width: 32, height: 32, layerViewModel: layerVM))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Pixapper")
                    .font(.headline)

                Spacer()

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
                ToolPanel(viewModel: canvasViewModel)

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
            if keyPress.characters == " " {
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
