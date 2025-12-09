//
//  TimelinePanel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct TimelinePanel: View {
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Playback controls
            HStack(spacing: 12) {
                // Play/Pause button
                Button(action: { viewModel.togglePlayback() }) {
                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 16))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .help("Play/Pause (Space)")

                // FPS selector
                HStack(spacing: 4) {
                    Text("FPS")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Picker("FPS", selection: Binding(
                        get: { viewModel.settings.fps },
                        set: { viewModel.setFPS($0) }
                    )) {
                        Text("1").tag(1)
                        Text("6").tag(6)
                        Text("12").tag(12)
                        Text("24").tag(24)
                        Text("30").tag(30)
                        Text("60").tag(60)
                    }
                    .labelsHidden()
                    .frame(width: 70)
                }

                // Speed selector
                HStack(spacing: 4) {
                    Text("Speed")
                        .font(.callout)
                        .foregroundColor(.secondary)
                    Picker("Speed", selection: Binding(
                        get: { viewModel.settings.playbackSpeed },
                        set: { viewModel.setPlaybackSpeed($0) }
                    )) {
                        Text("0.25x").tag(0.25)
                        Text("0.5x").tag(0.5)
                        Text("1x").tag(1.0)
                        Text("2x").tag(2.0)
                        Text("4x").tag(4.0)
                    }
                    .labelsHidden()
                    .frame(width: 80)
                }

                // Loop toggle
                Toggle("", isOn: Binding(
                    get: { viewModel.settings.isLooping },
                    set: { _ in viewModel.toggleLoop() }
                ))
                .toggleStyle(.switch)
                .help("Loop")

                Spacer()

                // Onion skin toggle
                Button(action: { viewModel.toggleOnionSkin() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle.lefthalf.filled")
                            .font(.system(size: 14))
                        Text("Onion")
                            .font(.callout)
                    }
                    .foregroundColor(viewModel.settings.onionSkinEnabled ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Onion Skin (O)")

                Spacer()

                // Frame indicator
                Text("Frame: \(viewModel.currentFrameIndex + 1)/\(viewModel.frames.count)")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Frame scrubber
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(Array(viewModel.frames.enumerated()), id: \.element.id) { index, frame in
                        FrameThumbnail(
                            frameNumber: index + 1,
                            isSelected: index == viewModel.currentFrameIndex,
                            onSelect: { viewModel.selectFrame(at: index) }
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(height: 80)

            Divider()

            // Frame operations
            HStack(spacing: 12) {
                Button(action: { viewModel.addFrame() }) {
                    Image(systemName: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Add Frame")

                Button(action: {
                    if viewModel.frames.count > 1 {
                        viewModel.deleteFrame(at: viewModel.currentFrameIndex)
                    }
                }) {
                    Image(systemName: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.frames.count <= 1)
                .help("Delete Frame")

                Button(action: {
                    viewModel.duplicateFrame(at: viewModel.currentFrameIndex)
                }) {
                    Image(systemName: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .help("Duplicate Frame")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
}

struct FrameThumbnail: View {
    let frameNumber: Int
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Thumbnail placeholder
            Rectangle()
                .fill(Color(nsColor: .textBackgroundColor))
                .frame(width: 50, height: 50)
                .overlay(
                    Text("\(frameNumber)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                )
                .cornerRadius(4)

            // Frame number
            Text("\(frameNumber)")
                .font(.caption2)
                .foregroundColor(isSelected ? .primary : .secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
}
