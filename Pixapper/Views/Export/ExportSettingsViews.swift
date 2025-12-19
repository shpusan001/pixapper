//
//  ExportSettingsViews.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/18/25.
//

import SwiftUI

// MARK: - Single Image Settings

struct SingleImageSettings: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export current frame as PNG")
                .font(.callout)
                .foregroundColor(Constants.Theme.textSecondary)

            HStack {
                Text("Current Frame:")
                    .foregroundColor(Constants.Theme.textPrimary)
                Spacer()
                Text("\(viewModel.timelineViewModel.currentFrameIndex + 1) / \(viewModel.timelineViewModel.totalFrames)")
                    .foregroundColor(Constants.Theme.accentBlue)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(6)

            Spacer()
        }
    }
}

// MARK: - Sprite Sheet Settings

struct SpriteSheetSettings: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Combine all frames into a single sprite sheet")
                .font(.callout)
                .foregroundColor(Constants.Theme.textSecondary)

            // Layout
            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Theme.textPrimary)

                Picker("", selection: $viewModel.spriteSheetLayout) {
                    ForEach(SpriteSheetLayout.allCases) { layout in
                        Text(layout.rawValue).tag(layout)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Grid settings (only show when Grid is selected)
            if viewModel.spriteSheetLayout == .grid {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Grid Size")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Theme.textPrimary)

                    HStack(spacing: 12) {
                        // Columns
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Columns")
                                .font(.caption)
                                .foregroundColor(Constants.Theme.textSecondary)
                            HStack {
                                Button("-") {
                                    if viewModel.spriteSheetGridColumns > 1 {
                                        viewModel.spriteSheetGridColumns -= 1
                                    }
                                }
                                .buttonStyle(GridStepperButtonStyle())

                                Text("\(viewModel.spriteSheetGridColumns)")
                                    .font(.callout)
                                    .foregroundColor(Constants.Theme.accentBlue)
                                    .frame(width: 40)

                                Button("+") {
                                    viewModel.spriteSheetGridColumns += 1
                                }
                                .buttonStyle(GridStepperButtonStyle())
                            }
                        }

                        // Rows
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Rows")
                                .font(.caption)
                                .foregroundColor(Constants.Theme.textSecondary)
                            HStack {
                                Button("-") {
                                    if viewModel.spriteSheetGridRows > 1 {
                                        viewModel.spriteSheetGridRows -= 1
                                    }
                                }
                                .buttonStyle(GridStepperButtonStyle())

                                Text("\(viewModel.spriteSheetGridRows)")
                                    .font(.callout)
                                    .foregroundColor(Constants.Theme.accentBlue)
                                    .frame(width: 40)

                                Button("+") {
                                    viewModel.spriteSheetGridRows += 1
                                }
                                .buttonStyle(GridStepperButtonStyle())
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(6)
                }
            }

            // Padding
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Padding")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Theme.textPrimary)
                    Spacer()
                    Text("\(viewModel.spriteSheetPadding)px")
                        .font(.callout)
                        .foregroundColor(Constants.Theme.accentBlue)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.spriteSheetPadding) },
                        set: { viewModel.spriteSheetPadding = Int($0) }
                    ),
                    in: 0...16,
                    step: 1
                )
                .accentColor(Constants.Theme.accentBlue)
            }

            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Constants.Theme.accentBlue)
                Text("\(viewModel.timelineViewModel.totalFrames) frames will be combined")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(6)

            Spacer()
        }
    }
}

// MARK: - Grid Stepper Button Style

struct GridStepperButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundColor(Constants.Theme.textPrimary)
            .frame(width: 30, height: 30)
            .background(configuration.isPressed ? Constants.Theme.hoverBackground : Constants.Theme.sectionBackground)
            .cornerRadius(4)
    }
}

// MARK: - PNG Sequence Settings

struct PNGSequenceSettings: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export each frame as a separate PNG file")
                .font(.callout)
                .foregroundColor(Constants.Theme.textSecondary)

            // Base Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Base Name")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Theme.textPrimary)

                TextField("Base name", text: $viewModel.sequenceBaseName)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(6)
            }

            // Preview naming
            VStack(alignment: .leading, spacing: 4) {
                Text("Output files:")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textSecondary)
                Text("\(viewModel.sequenceBaseName)_001.png")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textPrimary)
                    .fontDesign(.monospaced)
                Text("\(viewModel.sequenceBaseName)_002.png")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textPrimary)
                    .fontDesign(.monospaced)
                Text("...")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(6)

            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Constants.Theme.accentBlue)
                Text("\(viewModel.timelineViewModel.totalFrames) files will be created")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(6)

            Spacer()
        }
    }
}

// MARK: - GIF Settings

struct GIFSettings: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export as animated GIF")
                .font(.callout)
                .foregroundColor(Constants.Theme.textSecondary)

            // FPS
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Frame Rate")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Theme.textPrimary)
                    Spacer()
                    Text("\(viewModel.gifFPS) FPS")
                        .font(.callout)
                        .foregroundColor(Constants.Theme.accentBlue)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.gifFPS) },
                        set: { viewModel.gifFPS = Int($0) }
                    ),
                    in: 1...60,
                    step: 1
                )
                .accentColor(Constants.Theme.accentBlue)
            }

            // Loop Count
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Loop Count")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Theme.textPrimary)
                    Spacer()
                    Text(viewModel.gifLoopCount == 0 ? "Infinite" : "\(viewModel.gifLoopCount)")
                        .font(.callout)
                        .foregroundColor(Constants.Theme.accentBlue)
                }

                HStack(spacing: 8) {
                    Button("Infinite") {
                        viewModel.gifLoopCount = 0
                    }
                    .buttonStyle(OptionButtonStyle(isSelected: viewModel.gifLoopCount == 0))

                    Button("Once") {
                        viewModel.gifLoopCount = 1
                    }
                    .buttonStyle(OptionButtonStyle(isSelected: viewModel.gifLoopCount == 1))

                    Button("Custom") {
                        if viewModel.gifLoopCount <= 1 {
                            viewModel.gifLoopCount = 3
                        }
                    }
                    .buttonStyle(OptionButtonStyle(isSelected: viewModel.gifLoopCount > 1))
                }

                if viewModel.gifLoopCount > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(viewModel.gifLoopCount) },
                            set: { viewModel.gifLoopCount = Int($0) }
                        ),
                        in: 2...100,
                        step: 1
                    )
                    .accentColor(Constants.Theme.accentBlue)
                }
            }

            // Render Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Render Mode")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Theme.textPrimary)

                Picker("", selection: $viewModel.gifRenderMode) {
                    ForEach(GIFRenderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(viewModel.gifRenderMode == .pixelPerfect ?
                     "Sharp pixels with no interpolation" :
                     "Smooth scaling with interpolation")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(6)
            }

            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Constants.Theme.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.timelineViewModel.totalFrames) frames")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                    Text("Duration: \(String(format: "%.2f", Double(viewModel.timelineViewModel.totalFrames) / Double(viewModel.gifFPS)))s")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(6)

            Spacer()
        }
    }
}

// MARK: - MP4 Settings

struct MP4Settings: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export as MP4 video (H.264)")
                .font(.callout)
                .foregroundColor(Constants.Theme.textSecondary)

            // FPS
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Frame Rate")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(Constants.Theme.textPrimary)
                    Spacer()
                    Text("\(viewModel.mp4FPS) FPS")
                        .font(.callout)
                        .foregroundColor(Constants.Theme.accentBlue)
                }

                Slider(
                    value: Binding(
                        get: { Double(viewModel.mp4FPS) },
                        set: { viewModel.mp4FPS = Int($0) }
                    ),
                    in: 1...60,
                    step: 1
                )
                .accentColor(Constants.Theme.accentBlue)
            }

            // Quality
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Theme.textPrimary)

                Picker("", selection: $viewModel.mp4Quality) {
                    ForEach(MP4Quality.allCases) { quality in
                        Text(quality.rawValue).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Render Mode
            VStack(alignment: .leading, spacing: 8) {
                Text("Render Mode")
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(Constants.Theme.textPrimary)

                Picker("", selection: $viewModel.mp4RenderMode) {
                    ForEach(MP4RenderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(viewModel.mp4RenderMode == .pixelPerfect ?
                     "Sharp pixels with no interpolation" :
                     "Smooth scaling with interpolation")
                    .font(.caption)
                    .foregroundColor(Constants.Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Constants.Theme.sectionBackground)
                    .cornerRadius(6)
            }

            // Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(Constants.Theme.accentBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(viewModel.timelineViewModel.totalFrames) frames")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                    Text("Duration: \(String(format: "%.2f", Double(viewModel.timelineViewModel.totalFrames) / Double(viewModel.mp4FPS)))s")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                    Text("Bitrate: \(viewModel.mp4Quality.bitrate / 1_000_000) Mbps")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)
            .cornerRadius(6)

            Spacer()
        }
    }
}

// MARK: - Custom Button Style

struct OptionButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.callout)
            .foregroundColor(isSelected ? .white : Constants.Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Constants.Theme.accentBlue : Constants.Theme.sectionBackground)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Constants.Theme.accentBlue : Constants.Theme.divider, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}
