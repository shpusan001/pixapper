//
//  TimelinePanelNew.swift
//  Pixapper
//
//  Created by Claude on 2025-12-16.
//  완전히 새로운 타임라인 레이아웃
//

import SwiftUI
import AppKit

// MARK: - Frame Click Handler NSView

struct FrameClickHandler: NSViewRepresentable {
    let frameIndex: Int
    let layerIndex: Int
    let onClick: (Int, Int, NSEvent.ModifierFlags) -> Void

    func makeNSView(context: Context) -> FrameClickNSView {
        let view = FrameClickNSView()
        view.frameIndex = frameIndex
        view.layerIndex = layerIndex
        view.onClick = onClick
        return view
    }

    func updateNSView(_ nsView: FrameClickNSView, context: Context) {
        nsView.frameIndex = frameIndex
        nsView.layerIndex = layerIndex
        nsView.onClick = onClick
    }
}

class FrameClickNSView: NSView {
    var frameIndex: Int = 0
    var layerIndex: Int = 0
    var onClick: ((Int, Int, NSEvent.ModifierFlags) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?(frameIndex, layerIndex, event.modifierFlags)
    }
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGPoint = .zero

    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {
        value = nextValue()
    }
}

struct TimelinePanelNew: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var commandManager: CommandManager

    // 레이아웃 State
    @State private var layerColumnWidth: CGFloat = 200
    @State private var isDraggingSplitter: Bool = false
    @State private var splitterDragStart: CGFloat = 0
    @State private var cellSize: CGFloat = Constants.Layout.Timeline.cellSize
    @State private var horizontalScrollOffset: CGFloat = 0
    @State private var verticalScrollOffset: CGFloat = 0

    // 기존 State
    @State private var editingLayerIndex: Int?
    @State private var editingLayerName: String = ""
    @State private var draggingLayerIndex: Int?

    // Constants
    private let minLayerColumnWidth: CGFloat = 150
    private let maxLayerColumnWidth: CGFloat = 400
    private let splitterWidth: CGFloat = 1
    private let minCellSize: CGFloat = 24
    private let maxCellSize: CGFloat = 96
    private let headerHeight: CGFloat = Constants.Layout.Timeline.rowHeight

    var body: some View {
        VStack(spacing: 0) {
            divider
            PlaybackControlsView(viewModel: viewModel)
            divider

            // Toolbar with zoom control
            HStack(spacing: 12) {
                TimelineToolbarView(viewModel: viewModel, commandManager: commandManager)

                Spacer()

                // Zoom controls
                zoomControls
            }
            .frame(height: headerHeight)
            .padding(.horizontal, 10)
            .background(Constants.Theme.sectionBackground)

            divider

            // 메인 타임라인 영역
            mainTimelineArea
        }
        .background(Constants.Theme.panelBackground)
        .background(
            // Keyboard shortcuts for zoom
            VStack {
                Button("") {
                    cellSize = min(maxCellSize, cellSize + 8)
                }
                .keyboardShortcut("+", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)

                Button("") {
                    cellSize = max(minCellSize, cellSize - 8)
                }
                .keyboardShortcut("-", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
            }
        )
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

            // 레이어 리스트 (스크롤 오프셋으로 동기화)
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { index in
                        layerInfoRow(index: index)
                    }
                }
                .offset(y: verticalScrollOffset)
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
            // 프레임 번호 헤더 (스크롤 오프셋으로 동기화)
            GeometryReader { headerGeometry in
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
                .offset(x: horizontalScrollOffset)
                .background(Constants.Theme.sectionBackground)
            }
            .frame(height: headerHeight)

            // 프레임 셀 그리드 + Playhead
            ZStack(alignment: .topLeading) {
                // 프레임 셀 그리드
                GeometryReader { geometry in
                    ScrollViewReader { scrollProxy in
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                                ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { layerIndex in
                                    frameRowForLayer(layerIndex: layerIndex)
                                }
                            }
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                            .background(
                                GeometryReader { contentGeometry in
                                    Color.clear.preference(
                                        key: ScrollOffsetPreferenceKey.self,
                                        value: contentGeometry.frame(in: .named("frameScrollView")).origin
                                    )
                                }
                            )
                        }
                        .coordinateSpace(name: "frameScrollView")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            horizontalScrollOffset = value.x
                            verticalScrollOffset = value.y
                        }
                        .onChange(of: viewModel.currentFrameIndex) { oldIndex, newIndex in
                            // 재생 중이거나 프레임 변경 시 자동 스크롤
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scrollProxy.scrollTo("frame_\(newIndex)", anchor: .center)
                            }
                        }
                    }
                }

                // Playhead 붉은 선 (프레임 왼쪽)
                Rectangle()
                    .fill(Constants.Theme.playheadRed)
                    .frame(width: 2)
                    .offset(
                        x: CGFloat(viewModel.currentFrameIndex) * cellSize + horizontalScrollOffset,
                        y: 0
                    )
                    .allowsHitTesting(false)
            }
        }
    }

    private func frameRowForLayer(layerIndex: Int) -> some View {
        let layer = viewModel.layerViewModel.layers[layerIndex]
        let isFirstLayer = layerIndex == viewModel.layerViewModel.layers.indices.first

        return HStack(spacing: 0) {
            ForEach(viewModel.frames) { frame in
                frameCellView(layer: layer, layerIndex: layerIndex, frameIndex: frame.index)
                    .id(isFirstLayer ? "frame_\(frame.index)" : nil)
            }
        }
        .frame(height: cellSize)
    }

    private func frameCellView(layer: Layer, layerIndex: Int, frameIndex: Int) -> some View {
        let isMultiSelected = viewModel.selectedFrameIndices.contains(frameIndex) &&
                             layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let spanPosition = viewModel.getFrameSpanPosition(frameIndex: frameIndex, layerId: layer.id)
        let hasContent = viewModel.hasFrameContent(frameIndex: frameIndex, layerId: layer.id)
        let effectivePixels = viewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layer.id)

        return ZStack {
            // Background
            cellBackground(spanPosition: spanPosition, hasContent: hasContent)

            // Multi-selection background
            if isMultiSelected {
                Constants.Theme.accentBlue.opacity(0.15)
            }

            // Thumbnail for keyframes with content
            if spanPosition == .keyframeStart && hasContent, let pixels = effectivePixels {
                CellThumbnailView(pixels: pixels, size: cellSize - 8)
                    .padding(4)
            }

            // Keyframe indicator
            VStack {
                HStack {
                    keyframeMarker(spanPosition: spanPosition, hasContent: hasContent)
                        .padding(4)
                    Spacer()
                }
                Spacer()
            }
        }
        .frame(width: cellSize, height: cellSize)
        .overlay(
            RoundedRectangle(cornerRadius: 1)
                .strokeBorder(Constants.Theme.divider.opacity(0.3), lineWidth: 0.5)
        )
        .overlay(
            // Multi-selection border (blue)
            RoundedRectangle(cornerRadius: 1)
                .strokeBorder(Constants.Theme.accentBlue, lineWidth: isMultiSelected ? 2 : 0)
        )
        .overlay(
            FrameClickHandler(
                frameIndex: frameIndex,
                layerIndex: layerIndex,
                onClick: { fIndex, lIndex, modifiers in
                    handleFrameClick(frameIndex: fIndex, layerIndex: lIndex, modifiers: modifiers)
                }
            )
        )
        .contentShape(Rectangle())
        .contextMenu {
            frameContextMenu(frameIndex: frameIndex, layerId: layer.id)
        }
    }

    // MARK: - Selection Handlers

    private func handleFrameClick(frameIndex: Int, layerIndex: Int, modifiers: NSEvent.ModifierFlags) {
        viewModel.layerViewModel.selectedLayerIndex = layerIndex

        if modifiers.contains(.command) {
            // Cmd+클릭: 토글 선택
            if viewModel.selectedFrameIndices.contains(frameIndex) {
                viewModel.selectedFrameIndices.remove(frameIndex)
                if viewModel.selectedFrameIndices.isEmpty {
                    viewModel.selectionAnchor = nil
                }
            } else {
                viewModel.selectedFrameIndices.insert(frameIndex)
                viewModel.selectionAnchor = frameIndex
                viewModel.currentFrameIndex = frameIndex
                viewModel.loadFrame(at: frameIndex)
            }
        } else if modifiers.contains(.shift) {
            // Shift+클릭: 범위 선택
            let anchor = viewModel.selectionAnchor ?? viewModel.currentFrameIndex
            let range = min(anchor, frameIndex)...max(anchor, frameIndex)
            viewModel.selectedFrameIndices = Set(range)
            viewModel.currentFrameIndex = frameIndex
            viewModel.loadFrame(at: frameIndex)
        } else {
            // 일반 클릭: 단일 선택
            viewModel.selectedFrameIndices = [frameIndex]
            viewModel.selectionAnchor = frameIndex
            viewModel.currentFrameIndex = frameIndex
            viewModel.loadFrame(at: frameIndex)
        }
    }

    @ViewBuilder
    private func frameContextMenu(frameIndex: Int, layerId: UUID) -> some View {
        let selectedIndices = viewModel.selectedFrameIndices.isEmpty ? [frameIndex] : viewModel.selectedFrameIndices

        Button("Copy") {
            viewModel.copyFrames(frameIndices: selectedIndices, layerId: layerId)
        }
        .keyboardShortcut("c", modifiers: .command)

        Button("Paste") {
            let command = PasteFramesCommand(
                timelineViewModel: viewModel,
                startIndex: frameIndex,
                layerId: layerId
            )
            commandManager.performCommand(command)
        }
        .keyboardShortcut("v", modifiers: .command)
        .disabled(viewModel.frameClipboard.isEmpty)

        Button("Cut") {
            let command = CutFramesCommand(
                timelineViewModel: viewModel,
                frameIndices: selectedIndices,
                layerId: layerId
            )
            commandManager.performCommand(command)
        }
        .keyboardShortcut("x", modifiers: .command)

        Divider()

        Button("Delete", role: .destructive) {
            // 선택된 프레임 삭제 로직
            for index in selectedIndices.sorted(by: >) {
                if viewModel.layerViewModel.layers.first(where: { $0.id == layerId })?.timeline.isKeyframe(at: index) == true {
                    let command = DeleteFrameInLayerCommand(
                        timelineViewModel: viewModel,
                        index: index,
                        layerId: layerId
                    )
                    commandManager.performCommand(command)
                }
            }
            viewModel.selectedFrameIndices.removeAll()
        }
    }

    @ViewBuilder
    private func keyframeMarker(spanPosition: TimelineViewModel.FrameSpanPosition, hasContent: Bool) -> some View {
        switch spanPosition {
        case .keyframeStart:
            if hasContent {
                // Filled diamond for keyframe with content
                Diamond()
                    .fill(Constants.Theme.textPrimary)
                    .frame(width: 7, height: 7)
            } else {
                // Empty circle for blank keyframe
                Circle()
                    .stroke(Constants.Theme.textPrimary, lineWidth: 1.5)
                    .frame(width: 7, height: 7)
            }
        case .extended:
            // Small dot for extended frames
            if hasContent {
                Circle()
                    .fill(Constants.Theme.textSecondary)
                    .frame(width: 3, height: 3)
            }
        case .end:
            // End marker
            if hasContent {
                Rectangle()
                    .fill(Constants.Theme.textSecondary)
                    .frame(width: 1.5, height: 6)
            }
        case .empty:
            EmptyView()
        }
    }

    private func cellBackground(spanPosition: TimelineViewModel.FrameSpanPosition, hasContent: Bool) -> Color {
        switch spanPosition {
        case .keyframeStart:
            return Constants.Theme.sectionBackground
        case .extended, .end:
            return Constants.Theme.sectionBackground.opacity(0.3)
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

    // MARK: - Zoom Controls

    private var zoomControls: some View {
        HStack(spacing: 4) {
            Text("ZOOM")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Constants.Theme.textSecondary)

            Button(action: {
                cellSize = max(minCellSize, cellSize - 8)
            }) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Zoom Out (Cmd -)")

            Slider(value: $cellSize, in: minCellSize...maxCellSize, step: 4)
                .frame(width: 80)
                .tint(Constants.Theme.accentBlue)

            Button(action: {
                cellSize = min(maxCellSize, cellSize + 8)
            }) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Zoom In (Cmd +)")

            Text("\(Int((cellSize / maxCellSize) * 100))%")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: 32, alignment: .trailing)
        }
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(Constants.Theme.divider)
            .frame(height: 1)
    }
}
