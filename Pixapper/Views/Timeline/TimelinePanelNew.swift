//
//  TimelinePanelNew.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//  완전히 새로운 타임라인 레이아웃
//

import SwiftUI

struct TimelinePanelNew: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var commandManager: CommandManager

    // 레이아웃 State
    @State private var layerColumnWidth: CGFloat = 200
    @State private var isDraggingSplitter: Bool = false
    @State private var splitterDragStart: CGFloat = 0

    // 기존 State
    @State private var editingLayerIndex: Int?
    @State private var editingLayerName: String = ""
    @State private var draggingLayerIndex: Int?

    // Constants
    private let minLayerColumnWidth: CGFloat = 150
    private let maxLayerColumnWidth: CGFloat = 400
    private let splitterWidth: CGFloat = 1
    private let cellSize: CGFloat = Constants.Layout.Timeline.cellSize
    private let headerHeight: CGFloat = Constants.Layout.Timeline.rowHeight

    var body: some View {
        VStack(spacing: 0) {
            divider
            PlaybackControlsView(viewModel: viewModel)
            divider
            TimelineToolbarView(viewModel: viewModel, commandManager: commandManager)
            divider

            // 메인 타임라인 영역
            mainTimelineArea
        }
        .background(Constants.Theme.panelBackground)
    }

    // MARK: - Main Timeline Area

    private var mainTimelineArea: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // 왼쪽: 레이어 컬럼
                layerColumn
                    .frame(width: layerColumnWidth)

                // 중간: 드래그 분할선
                splitterDivider

                // 오른쪽: 프레임 그리드
                frameGrid
                    .frame(width: geometry.size.width - layerColumnWidth - splitterWidth)
            }
        }
    }

    // MARK: - Layer Column

    private var layerColumn: some View {
        VStack(spacing: 0) {
            // 헤더
            Text("LAYERS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(height: headerHeight)
                .frame(maxWidth: .infinity)
                .background(Constants.Theme.sectionBackground)

            // 레이어 리스트
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { index in
                        layerInfoRow(index: index)
                    }
                }
            }
        }
        .background(Constants.Theme.panelBackground)
    }

    private func layerInfoRow(index: Int) -> some View {
        let layer = viewModel.layerViewModel.layers[index]
        let isSelected = index == viewModel.layerViewModel.selectedLayerIndex

        return HStack(spacing: 8) {
            // Visibility
            Button(action: {
                viewModel.layerViewModel.toggleVisibility(at: index)
            }) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 10))
                    .foregroundColor(layer.isVisible ? Constants.Theme.textPrimary : Constants.Theme.textDisabled)
            }
            .buttonStyle(.plain)

            // Name
            Text(layer.name)
                .font(.system(size: 11))
                .foregroundColor(Constants.Theme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Opacity
            Text("\(Int(layer.opacity * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Constants.Theme.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(height: cellSize)
        .background(isSelected ? Constants.Theme.accentBlue.opacity(0.2) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.layerViewModel.selectedLayerIndex = index
        }
    }

    // MARK: - Frame Grid

    private var frameGrid: some View {
        VStack(spacing: 0) {
            // 프레임 번호 헤더
            frameHeaderRow

            // 프레임 셀 그리드
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { layerIndex in
                            frameRowForLayer(layerIndex: layerIndex)
                        }
                    }
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
        }
    }

    private var frameHeaderRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(viewModel.frames) { frame in
                    Text("\(frame.index + 1)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(Constants.Theme.textSecondary)
                        .frame(width: cellSize, height: headerHeight)
                        .background(frame.index == viewModel.currentFrameIndex ?
                                  Constants.Theme.accentBlue.opacity(0.2) :
                                  Constants.Theme.sectionBackground)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            viewModel.selectFrame(at: frame.index)
                        }
                }
            }
        }
        .background(Constants.Theme.sectionBackground)
    }

    private func frameRowForLayer(layerIndex: Int) -> some View {
        let layer = viewModel.layerViewModel.layers[layerIndex]

        return HStack(spacing: 0) {
            ForEach(viewModel.frames) { frame in
                frameCellView(layer: layer, layerIndex: layerIndex, frameIndex: frame.index)
            }
        }
        .frame(height: cellSize)
    }

    private func frameCellView(layer: Layer, layerIndex: Int, frameIndex: Int) -> some View {
        let isSelected = frameIndex == viewModel.currentFrameIndex &&
                        layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let spanPosition = viewModel.getFrameSpanPosition(frameIndex: frameIndex, layerId: layer.id)
        let hasContent = viewModel.hasFrameContent(frameIndex: frameIndex, layerId: layer.id)

        return ZStack {
            // Background
            cellBackground(spanPosition: spanPosition, isSelected: isSelected)

            // Keyframe indicator
            if spanPosition == .keyframeStart && hasContent {
                Diamond()
                    .fill(Constants.Theme.textPrimary)
                    .frame(width: 6, height: 6)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .border(isSelected ? Constants.Theme.accentBlue : Color.clear, width: isSelected ? 2 : 0)
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectFrame(at: frameIndex)
            viewModel.layerViewModel.selectedLayerIndex = layerIndex
        }
    }

    private func cellBackground(spanPosition: TimelineViewModel.FrameSpanPosition, isSelected: Bool) -> Color {
        if isSelected {
            return Constants.Theme.accentBlue.opacity(0.3)
        }

        switch spanPosition {
        case .keyframeStart:
            return Constants.Theme.sectionBackground
        case .extended, .end:
            return Constants.Theme.sectionBackground.opacity(0.5)
        case .empty:
            return Constants.Theme.backgroundDark
        }
    }

    // MARK: - Splitter

    private var splitterDivider: some View {
        Rectangle()
            .fill(isDraggingSplitter ? Constants.Theme.accentBlue : Constants.Theme.divider)
            .frame(width: splitterWidth)
            .contentShape(Rectangle().inset(by: -4))  // 클릭 영역만 넓게
            .onHover { hovering in
                if hovering {
                    NSCursor.resizeLeftRight.push()
                } else {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        if !isDraggingSplitter {
                            splitterDragStart = layerColumnWidth
                            isDraggingSplitter = true
                        }
                        let newWidth = splitterDragStart + value.translation.width
                        layerColumnWidth = max(minLayerColumnWidth, min(maxLayerColumnWidth, newWidth))
                    }
                    .onEnded { _ in
                        isDraggingSplitter = false
                    }
            )
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Constants.Theme.divider)
            .frame(height: 1)
    }
}
