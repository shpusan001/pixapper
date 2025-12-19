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

// MARK: - NSScrollView Wrapper for precise control

struct PreciseScrollView<Content: View>: NSViewRepresentable {
    let content: Content
    @Binding var scrollOffset: CGPoint
    let targetFrameIndex: Int
    let cellSize: CGFloat
    let viewportWidth: CGFloat
    let isPlaying: Bool

    init(
        scrollOffset: Binding<CGPoint>,
        targetFrameIndex: Int,
        cellSize: CGFloat,
        viewportWidth: CGFloat,
        isPlaying: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self._scrollOffset = scrollOffset
        self.targetFrameIndex = targetFrameIndex
        self.cellSize = cellSize
        self.viewportWidth = viewportWidth
        self.isPlaying = isPlaying
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasHorizontalScroller = true
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = false

        let hostingView = NSHostingView(rootView: content)
        hostingView.autoresizingMask = [.width, .height]
        scrollView.documentView = hostingView

        context.coordinator.scrollView = scrollView

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.scrollViewDidScroll),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        // Update content if needed
        if let hostingView = scrollView.documentView as? NSHostingView<Content> {
            hostingView.rootView = content
        }

        // 프레임 인덱스가 바뀌면 정확한 위치로 스크롤
        let targetX = CGFloat(targetFrameIndex) * cellSize - (viewportWidth / 2) + (cellSize / 2)
        let clampedX = max(0, targetX)
        let currentX = scrollView.contentView.bounds.origin.x

        if abs(currentX - clampedX) > 1 {
            let targetPoint = NSPoint(x: clampedX, y: scrollView.contentView.bounds.origin.y)

            if isPlaying {
                // 재생 중: 즉시 스크롤
                scrollView.contentView.scroll(to: targetPoint)
                scrollView.reflectScrolledClipView(scrollView.contentView)
                // 즉시 offset 동기화 (깜빡임 방지)
                DispatchQueue.main.async {
                    context.coordinator.scrollOffset = scrollView.contentView.bounds.origin
                }
            } else {
                // 수동 이동: 부드러운 애니메이션
                NSAnimationContext.runAnimationGroup({ ctx in
                    ctx.duration = 0.15
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    scrollView.contentView.animator().setBoundsOrigin(targetPoint)
                }, completionHandler: nil)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scrollOffset: $scrollOffset)
    }

    class Coordinator: NSObject {
        @Binding var scrollOffset: CGPoint
        weak var scrollView: NSScrollView?

        init(scrollOffset: Binding<CGPoint>) {
            self._scrollOffset = scrollOffset
        }

        @objc func scrollViewDidScroll(_ notification: Notification) {
            guard let scrollView = scrollView else { return }
            DispatchQueue.main.async {
                self.scrollOffset = scrollView.contentView.bounds.origin
            }
        }
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
                TimelineToolbarView(viewModel: viewModel, commandManager: commandManager, cellSize: $cellSize)

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
                layerColumnContent(availableHeight: geometry.size.height)
                    .frame(width: layerColumnWidth)

                // 중간: 드래그 분할선
                splitterDivider

                // 오른쪽: 프레임 그리드
                frameGridContent(availableHeight: geometry.size.height, availableWidth: geometry.size.width - layerColumnWidth - splitterWidth)
            }
        }
    }

    // MARK: - Layer Column

    private func layerColumnContent(availableHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 헤더
            Text("LAYERS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(height: headerHeight)
                .frame(maxWidth: .infinity)
                .background(Constants.Theme.sectionBackground)

            // 레이어 리스트 (스크롤 오프셋으로 동기화)
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { index in
                        layerInfoRow(index: index)
                    }
                }
                .offset(y: -verticalScrollOffset)
            }
            .frame(height: availableHeight - headerHeight)
            .clipped()
        }
        .frame(height: availableHeight)
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

    private func frameGridContent(availableHeight: CGFloat, availableWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // 프레임 번호 헤더 (스크롤 오프셋으로 동기화)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(viewModel.frames) { frame in
                        Text("\(frame.index + 1)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Constants.Theme.textSecondary)
                            .frame(width: cellSize, height: headerHeight)
                            .background(Constants.Theme.sectionBackground)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectFrame(at: frame.index)
                            }
                    }
                }
                .offset(x: -horizontalScrollOffset)
                .background(Constants.Theme.sectionBackground)
            }
            .frame(height: headerHeight)
            .clipped()

            // 프레임 셀 그리드 + Playhead
            ZStack(alignment: .topLeading) {
                // 프레임 셀 그리드
                PreciseScrollView(
                    scrollOffset: Binding(
                        get: { CGPoint(x: horizontalScrollOffset, y: verticalScrollOffset) },
                        set: { point in
                            horizontalScrollOffset = point.x
                            verticalScrollOffset = point.y
                        }
                    ),
                    targetFrameIndex: viewModel.currentFrameIndex,
                    cellSize: cellSize,
                    viewportWidth: availableWidth,
                    isPlaying: viewModel.isPlaying
                ) {
                    LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
                        ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { layerIndex in
                            frameRowForLayer(layerIndex: layerIndex)
                        }
                    }
                    .frame(minWidth: availableWidth, minHeight: availableHeight - headerHeight, alignment: .topLeading)
                }

                // Playhead 붉은 선
                playheadView
            }
            .frame(height: availableHeight - headerHeight)
            .clipped()
        }
        .frame(width: availableWidth, height: availableHeight)
    }

    @ViewBuilder
    private var playheadView: some View {
        GeometryReader { geo in
            let contentWidth = CGFloat(viewModel.frames.count) * cellSize
            let viewportWidth = geo.size.width
            let maxScrollX = max(0, contentWidth - viewportWidth)
            let idealCenterScroll = CGFloat(viewModel.currentFrameIndex) * cellSize - (viewportWidth / 2) + (cellSize / 2)
            let clampedScroll = max(0, min(idealCenterScroll, maxScrollX))
            let isAtStart = clampedScroll <= 0
            let isAtEnd = clampedScroll >= maxScrollX

            Rectangle()
                .fill(Constants.Theme.playheadRed)
                .frame(width: 2)
                .offset(x: {
                    if isAtStart || isAtEnd {
                        // 양 끝: 프레임 위치 따라감
                        return CGFloat(viewModel.currentFrameIndex) * cellSize - horizontalScrollOffset
                    } else {
                        // 중간: 화면 중앙 고정
                        return viewportWidth / 2
                    }
                }(), y: 0)
                .allowsHitTesting(false)
        }
        .allowsHitTesting(false)
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
                CellThumbnailView(pixels: pixels, size: cellSize - 8, palette: viewModel.pixelStateManager.currentPalette)
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
            let command = DeleteFramesCommand(
                timelineViewModel: viewModel,
                frameIndices: selectedIndices,
                layerId: layerId
            )
            commandManager.performCommand(command)
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
