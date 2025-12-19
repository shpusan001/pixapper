//
//  ExportView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: ExportViewModel

    init(timelineViewModel: TimelineViewModel, canvasWidth: Int, canvasHeight: Int) {
        _viewModel = StateObject(wrappedValue: ExportViewModel(
            timelineViewModel: timelineViewModel,
            canvasWidth: canvasWidth,
            canvasHeight: canvasHeight
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .background(Constants.Theme.divider)

            // Main content: Settings + Preview
            HStack(spacing: 0) {
                // Left: Settings Panel
                settingsPanel
                    .frame(width: 320)

                Divider()
                    .background(Constants.Theme.divider)

                // Right: Preview Panel
                previewPanel
                    .frame(width: 360)
            }
            .frame(height: 500)

            Divider()
                .background(Constants.Theme.divider)

            // Footer: Export Button
            footerView
        }
        .background(Constants.Theme.panelBackground)
        .onAppear {
            viewModel.generatePreview()
        }
        .onDisappear {
            viewModel.cancelExport()
        }
        .alert("Export Failed", isPresented: $viewModel.showingErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 12) {
            Text("Export")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(Constants.Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Format tabs
            HStack(spacing: 0) {
                ForEach(ExportFormat.allCases) { format in
                    FormatTabButton(
                        format: format,
                        isSelected: viewModel.selectedFormat == format
                    ) {
                        viewModel.selectedFormat = format
                    }
                }
            }
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(8)
        }
        .padding(20)
    }

    // MARK: - Settings Panel

    private var settingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Group {
                    switch viewModel.selectedFormat {
                    case .singleImage:
                        SingleImageSettings(viewModel: viewModel)
                    case .spriteSheet:
                        SpriteSheetSettings(viewModel: viewModel)
                    case .pngSequence:
                        PNGSequenceSettings(viewModel: viewModel)
                    case .gif:
                        GIFSettings(viewModel: viewModel)
                    case .mp4:
                        MP4Settings(viewModel: viewModel)
                    }
                }
                .padding(20)
            }
        }
        .background(Constants.Theme.panelBackground)
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        ExportPreviewView(viewModel: viewModel)
            .padding(20)
            .background(Constants.Theme.backgroundDark)
    }

    // MARK: - Footer

    private var footerView: some View {
        VStack(spacing: 12) {
            // Progress indicator
            if viewModel.isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: viewModel.exportProgress, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: Constants.Theme.accentBlue))

                    Text("Exporting... \(Int(viewModel.exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
            }

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    viewModel.cancelExport()
                    dismiss()
                }
                .buttonStyle(SecondaryButtonStyle())

                Spacer()

                Button("Export") {
                    viewModel.performExport {
                        dismiss()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(viewModel.isExporting)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Format Tab Button

struct FormatTabButton: View {
    let format: ExportFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: format.icon)
                    .font(.system(size: 20))
                Text(format.rawValue)
                    .font(.caption)
            }
            .foregroundColor(isSelected ? .white : Constants.Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Constants.Theme.accentBlue : Constants.Theme.sectionBackground.opacity(0.01))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

// MARK: - Custom Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .background(
                configuration.isPressed ?
                    Constants.Theme.accentBlueHover :
                    Constants.Theme.accentBlue
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(Constants.Theme.textPrimary)
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Constants.Theme.divider, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
