//
//  PlaybackControlsView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// 타임라인 재생 컨트롤 섹션
/// - 재생/정지, 프레임 네비게이션
/// - FPS 및 재생 속도 설정
/// - Loop 및 Onion Skin 토글
struct PlaybackControlsView: View {
    @ObservedObject var viewModel: TimelineViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Left: Playback & Navigation
            HStack(spacing: 2) {
                TimelineButton(
                    icon: viewModel.isPlaying ? "pause.fill" : "play.fill",
                    size: 24,
                    tooltip: "Play/Pause (Space)"
                ) {
                    viewModel.togglePlayback()
                }

                Rectangle()
                    .fill(Constants.Theme.divider)
                    .frame(width: 1, height: 16)
                    .padding(.horizontal, 4)

                TimelineButton(icon: "chevron.left", size: 20, tooltip: "Previous Frame (,)") {
                    viewModel.previousFrame()
                }

                Text("\(viewModel.currentFrameIndex + 1)/\(viewModel.totalFrames)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Constants.Theme.textPrimary)
                    .frame(minWidth: 45)

                TimelineButton(icon: "chevron.right", size: 20, tooltip: "Next Frame (.)") {
                    viewModel.nextFrame()
                }
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 16)
                .padding(.horizontal, 4)

            // Center: FPS & Speed
            HStack(spacing: 6) {
                Picker("", selection: Binding(
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
                .frame(width: 50)
                .pickerStyle(.menu)

                Text("FPS")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(Constants.Theme.textSecondary)
            }

            Picker("", selection: Binding(
                get: { viewModel.settings.playbackSpeed },
                set: { viewModel.setPlaybackSpeed($0) }
            )) {
                Text("0.25×").tag(0.25)
                Text("0.5×").tag(0.5)
                Text("1×").tag(1.0)
                Text("2×").tag(2.0)
                Text("4×").tag(4.0)
            }
            .labelsHidden()
            .frame(width: 55)
            .pickerStyle(.menu)

            Spacer()

            // Right: Options
            HStack(spacing: 4) {
                TimelineToggleButton(
                    icon: "repeat",
                    text: "Loop",
                    isOn: viewModel.settings.isLooping,
                    tooltip: "Loop"
                ) {
                    viewModel.toggleLoop()
                }

                TimelineToggleButton(
                    icon: "circle.lefthalf.filled",
                    text: "Onion",
                    isOn: viewModel.settings.onionSkinEnabled,
                    tooltip: "Onion Skin (O)"
                ) {
                    viewModel.toggleOnionSkin()
                }
            }
        }
        .frame(height: Constants.Layout.Timeline.rowHeight)
        .padding(.horizontal, 10)
        .background(Constants.Theme.panelBackground)
    }
}
