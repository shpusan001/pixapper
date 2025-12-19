//
//  TimelineToolbarView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// 타임라인 작업 툴바 (레이어, 키프레임, 프레임 조작)
struct TimelineToolbarView: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var commandManager: CommandManager
    @Binding var cellSize: CGFloat

    let minCellSize: CGFloat = 48
    let maxCellSize: CGFloat = 96

    var body: some View {
        HStack(spacing: 12) {
            // LAYER
            toolbarSection(title: "LAYER") {
                toolbarButton(icon: "plus.square", text: "Add", tooltip: "Add Layer") {
                    let command = AddLayerCommand(layerViewModel: viewModel.layerViewModel)
                    commandManager.performCommand(command)
                }

                toolbarButton(
                    icon: "minus.square",
                    text: "Delete",
                    tooltip: "Delete Layer",
                    disabled: viewModel.layerViewModel.layers.count <= 1
                ) {
                    if viewModel.layerViewModel.layers.count > 1 {
                        let command = DeleteLayerCommand(layerViewModel: viewModel.layerViewModel, index: viewModel.layerViewModel.selectedLayerIndex)
                        commandManager.performCommand(command)
                    }
                }
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 16)

            // KEYFRAME
            toolbarSection(title: "KEYFRAME") {
                let layerId = viewModel.layerViewModel.layers[viewModel.layerViewModel.selectedLayerIndex].id

                toolbarButton(icon: "scope", text: "Toggle", tooltip: "Toggle Keyframe (F6)") {
                    viewModel.toggleKeyframe(frameIndex: viewModel.currentFrameIndex, layerId: layerId)
                }

                toolbarButton(icon: "plus.circle.fill", text: "Insert", tooltip: "Insert Keyframe (F5)") {
                    let command = AddKeyframeWithContentCommand(
                        timelineViewModel: viewModel,
                        layerId: layerId
                    )
                    commandManager.performCommand(command)
                }

                toolbarButton(icon: "plus.circle.dashed", text: "Blank", tooltip: "Blank Keyframe (F7)") {
                    let command = AddBlankKeyframeCommand(
                        timelineViewModel: viewModel,
                        layerId: layerId,
                        canvasWidth: viewModel.canvasWidth,
                        canvasHeight: viewModel.canvasHeight
                    )
                    commandManager.performCommand(command)
                }
            }

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(width: 1, height: 16)

            // FRAME
            toolbarSection(title: "FRAME") {
                let layerId = viewModel.layerViewModel.layers[viewModel.layerViewModel.selectedLayerIndex].id

                toolbarButton(icon: "plus.square", text: "Extend", tooltip: "Extend Frame") {
                    let command = ExtendFrameCommand(
                        timelineViewModel: viewModel,
                        frameIndex: viewModel.currentFrameIndex,
                        layerId: layerId
                    )
                    commandManager.performCommand(command)
                }

                toolbarButton(icon: "minus.square", text: "Remove", tooltip: "Remove Frame") {
                    let command = DeleteFrameInLayerCommand(
                        timelineViewModel: viewModel,
                        index: viewModel.currentFrameIndex,
                        layerId: layerId
                    )
                    commandManager.performCommand(command)
                }
            }

            Spacer()

            // FRAME SIZE
            HStack(spacing: 6) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Theme.textSecondary)

                Slider(value: $cellSize, in: minCellSize...maxCellSize, step: 4)
                    .frame(width: 80)
                    .tint(Constants.Theme.accentBlue)

                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(Constants.Theme.textSecondary)

                Text("\(Int(cellSize))px")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Constants.Theme.textSecondary)
                    .frame(width: 32, alignment: .trailing)
            }
            .padding(.trailing, 4)
        }
        .frame(height: Constants.Layout.Timeline.rowHeight)
        .padding(.horizontal, 10)
        .background(Constants.Theme.sectionBackground)
    }

    // MARK: - Toolbar Helpers

    private func toolbarSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: 55, alignment: .leading)

            HStack(spacing: 4) {
                content()
            }
        }
    }

    private func toolbarButton(
        icon: String,
        text: String,
        tooltip: String,
        disabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        TimelineToolbarButton(
            icon: icon,
            text: text,
            tooltip: tooltip,
            disabled: disabled,
            action: action
        )
    }
}
