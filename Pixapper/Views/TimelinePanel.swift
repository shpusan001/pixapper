//
//  TimelinePanel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct TimelinePanel: View {
    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var commandManager: CommandManager

    @State private var editingLayerIndex: Int?
    @State private var editingLayerName: String = ""
    @State private var draggingLayerIndex: Int?
    @State private var dragStartFrameIndex: Int?  // 드래그 선택 시작점

    private let layerColumnWidth: CGFloat = Constants.Layout.Timeline.layerColumnWidth
    private let cellSize: CGFloat = Constants.Layout.Timeline.cellSize

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Playback controls
            playbackControls

            Divider()

            // 2D Grid: Layers × Frames
            GeometryReader { geometry in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        // Header row: Frame numbers
                        frameHeaderRow

                        // Layer rows (reversed for display: top = highest index)
                        ForEach(viewModel.layerViewModel.layers.indices.reversed(), id: \.self) { layerIndex in
                            let layer = viewModel.layerViewModel.layers[layerIndex]
                            layerRow(layer: layer, layerIndex: layerIndex)
                        }
                    }
                    .frame(minWidth: geometry.size.width, minHeight: geometry.size.height, alignment: .topLeading)
                }
            }
            .frame(maxHeight: 300)

            Divider()

            // Operations toolbar
            operationsToolbar
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.togglePlayback() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.bordered)
            .help("Play/Pause (Space)")

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

            Toggle("", isOn: Binding(
                get: { viewModel.settings.isLooping },
                set: { _ in viewModel.toggleLoop() }
            ))
            .toggleStyle(.switch)
            .help("Loop")

            Spacer()

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

            Text("Frame: \(viewModel.currentFrameIndex + 1)/\(viewModel.totalFrames)")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Frame Header Row

    private var frameHeaderRow: some View {
        HStack(spacing: 0) {
            // Layer column header
            Text("Layers")
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: layerColumnWidth, height: 30)
                .background(Color(nsColor: .controlBackgroundColor))

            // Frame numbers with drag selection support
            ForEach(0..<viewModel.totalFrames, id: \.self) { frameIndex in
                frameHeaderCell(frameIndex: frameIndex)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private func frameHeaderCell(frameIndex: Int) -> some View {
        let isSelected = viewModel.selectedFrameIndices.contains(frameIndex)
        let isCurrent = frameIndex == viewModel.currentFrameIndex

        return Text("\(frameIndex + 1)")
            .font(.caption)
            .fontWeight(isCurrent ? .bold : .regular)
            .foregroundColor(isCurrent ? .accentColor : .secondary)
            .frame(width: cellSize, height: 30)
            .background(
                Group {
                    if isSelected {
                        Color.accentColor.opacity(0.3)  // 다중 선택 강조
                    } else if isCurrent {
                        Color.accentColor.opacity(0.1)  // 현재 프레임
                    } else {
                        Color.clear
                    }
                }
            )
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)  // 5pt 이상 드래그 시 범위 선택
                    .onChanged { value in
                        // 드래그 시작
                        if dragStartFrameIndex == nil {
                            dragStartFrameIndex = frameIndex
                            viewModel.selectionAnchor = frameIndex
                        }

                        // 현재 위치까지 범위 선택
                        if let startIndex = dragStartFrameIndex {
                            let currentHoverIndex = calculateFrameIndex(from: value.location)
                            viewModel.updateDragSelection(from: startIndex, to: currentHoverIndex)
                        }
                    }
                    .onEnded { _ in
                        dragStartFrameIndex = nil

                        // 선택된 프레임 중 마지막 프레임으로 이동
                        if let lastSelected = viewModel.selectedFrameIndices.max() {
                            viewModel.selectFrame(at: lastSelected, clearSelection: false)
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    // 일반 탭: 단일 선택
                    viewModel.selectSingleFrame(at: frameIndex)
                }
            )
    }

    // 마우스 위치로부터 프레임 인덱스 계산
    private func calculateFrameIndex(from location: CGPoint) -> Int {
        let frameX = location.x
        let index = Int(frameX / cellSize)
        return min(max(index, 0), viewModel.totalFrames - 1)
    }

    // MARK: - Layer Row

    private func layerRow(layer: Layer, layerIndex: Int) -> some View {
        HStack(spacing: 0) {
            // Layer info column
            layerInfoColumn(layer: layer, layerIndex: layerIndex)

            // Frame cells for this layer
            ForEach(0..<viewModel.totalFrames, id: \.self) { frameIndex in
                cellView(
                    layer: layer,
                    layerIndex: layerIndex,
                    frameIndex: frameIndex
                )
            }
        }
    }

    // MARK: - Layer Info Column

    private func layerInfoColumn(layer: Layer, layerIndex: Int) -> some View {
        HStack(spacing: 4) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 14)

            // Visibility toggle
            Button(action: {
                viewModel.layerViewModel.toggleVisibility(at: layerIndex)
            }) {
                Image(systemName: layer.isVisible ? "eye" : "eye.slash")
                    .font(.system(size: 11))
                    .frame(width: 18, height: 18)
                    .foregroundColor(layer.isVisible ? .primary : .secondary)
            }
            .buttonStyle(.plain)

            // Layer name (editable)
            if editingLayerIndex == layerIndex {
                TextField("Name", text: $editingLayerName, onCommit: {
                    if !editingLayerName.isEmpty {
                        let oldName = layer.name
                        let command = RenameLayerCommand(layerViewModel: viewModel.layerViewModel, index: layerIndex, oldName: oldName, newName: editingLayerName)
                        commandManager.performCommand(command)
                    }
                    editingLayerIndex = nil
                })
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(maxWidth: .infinity)
            } else {
                Text(layer.name)
                    .font(.callout)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture(count: 2) {
                        editingLayerIndex = layerIndex
                        editingLayerName = layer.name
                    }
            }

            Text("\(Int(layer.opacity * 100))%")
                .font(.caption2)
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
        }
        .padding(.horizontal, 6)
        .frame(width: layerColumnWidth, height: cellSize)
        .background(
            Group {
                if layerIndex == viewModel.layerViewModel.selectedLayerIndex {
                    Color.accentColor.opacity(0.15)
                } else if draggingLayerIndex == layerIndex {
                    Color.accentColor.opacity(0.25)
                } else {
                    Color(nsColor: .controlBackgroundColor)
                }
            }
        )
        .contentShape(Rectangle())
        .opacity(draggingLayerIndex == layerIndex ? 0.5 : 1.0)
        .onTapGesture {
            if editingLayerIndex == nil {
                viewModel.layerViewModel.selectedLayerIndex = layerIndex
            }
        }
        .onDrag {
            draggingLayerIndex = layerIndex
            return NSItemProvider(object: "\(layerIndex)" as NSString)
        }
        .onDrop(of: [.text], delegate: LayerDropDelegate(
            layerIndex: layerIndex,
            draggingLayerIndex: $draggingLayerIndex,
            viewModel: viewModel.layerViewModel,
            commandManager: commandManager
        ))
        .contextMenu {
            Button("Rename") {
                editingLayerIndex = layerIndex
                editingLayerName = layer.name
            }
            Button("Duplicate") {
                viewModel.layerViewModel.duplicateLayer(at: layerIndex)
            }
            Divider()
            Button("Delete", role: .destructive) {
                if viewModel.layerViewModel.layers.count > 1 {
                    let command = DeleteLayerCommand(layerViewModel: viewModel.layerViewModel, index: layerIndex)
                    commandManager.performCommand(command)
                }
            }
            .disabled(viewModel.layerViewModel.layers.count <= 1)
        }
    }

    // MARK: - Cell View

    private func cellView(layer: Layer, layerIndex: Int, frameIndex: Int) -> some View {
        let isSelected = frameIndex == viewModel.currentFrameIndex && layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let isCurrentFrame = frameIndex == viewModel.currentFrameIndex
        let isCurrentLayer = layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let isMultiSelected = viewModel.selectedFrameIndices.contains(frameIndex)
        let effectivePixels = viewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layer.id)
        let spanPosition = viewModel.getFrameSpanPosition(frameIndex: frameIndex, layerId: layer.id)
        let hasContent = effectivePixels?.contains(where: { row in row.contains(where: { $0 != nil }) }) ?? false
        let isOutOfRange = effectivePixels == nil

        return ZStack {
            // Background
            cellBackground(spanPosition: spanPosition, isSelected: isSelected, isMultiSelected: isMultiSelected, isCurrentFrame: isCurrentFrame, isCurrentLayer: isCurrentLayer, isOutOfRange: isOutOfRange)

            // Thumbnail - 키프레임에만 표시
            if spanPosition == .keyframeStart, hasContent, let pixels = effectivePixels {
                CellThumbnailView(pixels: pixels, size: cellSize - 8)
            }

            // Keyframe marker
            if !isOutOfRange {
                cellMarker(spanPosition: spanPosition, hasContent: hasContent)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(spanClipShape(spanPosition: spanPosition))
        .overlay(
            // 셀 구분선 (미묘하게)
            Rectangle()
                .stroke(Color(nsColor: .separatorColor).opacity(isOutOfRange ? 0.15 : 0.3), lineWidth: 0.5)
        )
        .overlay(cellBorder(isSelected: isSelected, isMultiSelected: isMultiSelected))
        .overlay(
            // 현재 프레임 표시 (재생 헤드)
            Group {
                if isCurrentFrame {
                    VStack(spacing: 0) {
                        // 위쪽 삼각형 (재생 헤드)
                        Triangle()
                            .fill(Color.red)
                            .frame(width: 8, height: 6)

                        // 세로선
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 2, height: cellSize - 6)
                    }
                    .offset(x: -cellSize / 2 + 1)
                }
            }
        )
        .help(makeTooltipText(layer: layer, frameIndex: frameIndex, spanPosition: spanPosition, isOutOfRange: isOutOfRange))
        .contentShape(Rectangle())
        .opacity(isOutOfRange ? 0.4 : 1.0)
        .onTapGesture {
            viewModel.selectFrame(at: frameIndex)
            viewModel.layerViewModel.selectedLayerIndex = layerIndex
        }
        .contextMenu {
            if !isOutOfRange {
                contextMenuContent(layer: layer, frameIndex: frameIndex, spanPosition: spanPosition)
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func contextMenuContent(layer: Layer, frameIndex: Int, spanPosition: TimelineViewModel.FrameSpanPosition) -> some View {
        let targetFrames = viewModel.selectedFrameIndices.count > 1 ? viewModel.selectedFrameIndices : [frameIndex]
        let isMultiOp = targetFrames.count > 1
        let isKeyframe = spanPosition == .keyframeStart

        // F6: Toggle Keyframe
        Button(action: {
            let command = BatchKeyframeCommand(
                frameIndices: targetFrames,
                layerId: layer.id,
                timelineViewModel: viewModel,
                operation: .toggle
            )
            commandManager.performCommand(command)
        }) {
            if isKeyframe {
                Text(isMultiOp ? "Remove \(targetFrames.count) Keyframes" : "Remove Keyframe")
            } else {
                Text(isMultiOp ? "Convert to \(targetFrames.count) Keyframes (F6)" : "Convert to Keyframe (F6)")
            }
        }

        // F5: Extend Frame
        Button(action: {
            let command = BatchKeyframeCommand(
                frameIndices: targetFrames,
                layerId: layer.id,
                timelineViewModel: viewModel,
                operation: .extend
            )
            commandManager.performCommand(command)
        }) {
            Text(isMultiOp ? "Extend \(targetFrames.count) Frames (F5)" : "Extend Frame (F5)")
        }
        .disabled(spanPosition == .empty)

        // F7: Insert Blank Keyframe
        Button(action: {
            let command = BatchKeyframeCommand(
                frameIndices: targetFrames,
                layerId: layer.id,
                timelineViewModel: viewModel,
                operation: .insertBlank
            )
            commandManager.performCommand(command)
        }) {
            Text(isMultiOp ? "Insert \(targetFrames.count) Blank Keyframes (F7)" : "Insert Blank Keyframe (F7)")
        }

        Divider()

        // Clear Content
        Button(action: {
            let command = BatchKeyframeCommand(
                frameIndices: targetFrames,
                layerId: layer.id,
                timelineViewModel: viewModel,
                operation: .clear
            )
            commandManager.performCommand(command)
        }) {
            Text(isMultiOp ? "Clear \(targetFrames.count) Keyframes" : "Clear Content")
        }
        .disabled(!isKeyframe)
    }

    // MARK: - Cell Components

    @ViewBuilder
    private func cellBackground(spanPosition: TimelineViewModel.FrameSpanPosition, isSelected: Bool, isMultiSelected: Bool, isCurrentFrame: Bool, isCurrentLayer: Bool, isOutOfRange: Bool) -> some View {
        let backgroundColor: Color = {
            // Out of range: 매우 연한 회색
            if isOutOfRange {
                return Color(nsColor: .controlBackgroundColor).opacity(0.5)
            }

            // Selected: 미묘한 accentColor (macOS 스타일)
            if isSelected {
                return Color.accentColor.opacity(0.15)
            }

            // Multi-selected: 더 연한 accentColor
            if isMultiSelected {
                return Color.accentColor.opacity(0.08)
            }

            // Span 배경색 (회색 톤)
            switch spanPosition {
            case .keyframeStart:
                // 키프레임: 연한 회색
                return Color(nsColor: .separatorColor).opacity(0.5)
            case .extended, .end:
                // Extended span: 더 연한 회색
                return Color(nsColor: .separatorColor).opacity(0.25)
            case .empty:
                // Empty: 기본 배경색
                return Color(nsColor: .controlBackgroundColor)
            }
        }()

        return Rectangle()
            .fill(backgroundColor)
    }

    @ViewBuilder
    private func cellMarker(spanPosition: TimelineViewModel.FrameSpanPosition, hasContent: Bool) -> some View {
        VStack {
            HStack {
                Group {
                    switch spanPosition {
                    case .keyframeStart:
                        if hasContent {
                            // 키프레임 마커 (FCP 스타일 다이아몬드)
                            Diamond()
                                .fill(Color(nsColor: .labelColor))
                                .frame(width: 7, height: 7)
                        } else {
                            // 빈 키프레임 마커 (빈 원)
                            Circle()
                                .stroke(Color(nsColor: .labelColor), lineWidth: 1.5)
                                .frame(width: 7, height: 7)
                        }
                    case .extended:
                        // Extended: 마커 없음
                        EmptyView()
                    case .end:
                        // Span 끝: 구분선 제거
                        EmptyView()
                    case .empty:
                        // Empty: 마커 없음
                        EmptyView()
                    }
                }
                .padding(4)
                Spacer()
            }
            Spacer()
        }
    }

    private func spanClipShape(spanPosition: TimelineViewModel.FrameSpanPosition) -> AnyShape {
        // macOS/Final Cut Pro 스타일: 모두 직각
        return AnyShape(Rectangle())
    }

    @ViewBuilder
    private func cellBorder(isSelected: Bool, isMultiSelected: Bool) -> some View {
        if isSelected {
            // 선택된 셀: 두꺼운 accentColor 테두리
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
        } else if isMultiSelected {
            // 다중 선택: 얇은 accentColor 테두리
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 1.5)
        }
    }

    // MARK: - Helper Functions

    private func makeTooltipText(layer: Layer, frameIndex: Int, spanPosition: TimelineViewModel.FrameSpanPosition, isOutOfRange: Bool) -> String {
        if isOutOfRange {
            return "Out of range (layer has no data here)"
        }

        switch spanPosition {
        case .keyframeStart:
            if let span = viewModel.getKeyframeSpan(frameIndex: frameIndex, layerId: layer.id) {
                return "Keyframe (spans \(span.length) frame\(span.length > 1 ? "s" : ""))"
            }
            return "Keyframe"

        case .extended:
            if let span = viewModel.getKeyframeSpan(frameIndex: frameIndex, layerId: layer.id) {
                let relativePos = frameIndex - span.start + 1
                return "Extended from frame \(span.start + 1) (\(relativePos)/\(span.length))"
            }
            return "Extended frame"

        case .end:
            if let span = viewModel.getKeyframeSpan(frameIndex: frameIndex, layerId: layer.id) {
                return "End of span (from frame \(span.start + 1))"
            }
            return "End of span"

        case .empty:
            return "Empty frame (no keyframe data)"
        }
    }

    // MARK: - Operations Toolbar

    private var operationsToolbar: some View {
        HStack(spacing: 12) {
            // Layer operations
            Group {
                Button(action: {
                    let command = AddLayerCommand(layerViewModel: viewModel.layerViewModel)
                    commandManager.performCommand(command)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.rectangle.on.folder")
                        Text("Layer")
                    }
                }
                .help("Add Layer")

                Button(action: {
                    if viewModel.layerViewModel.layers.count > 1 {
                        let command = DeleteLayerCommand(layerViewModel: viewModel.layerViewModel, index: viewModel.layerViewModel.selectedLayerIndex)
                        commandManager.performCommand(command)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Layer")
                    }
                }
                .disabled(viewModel.layerViewModel.layers.count <= 1)
                .help("Delete Layer")
            }
            .buttonStyle(.bordered)

            Spacer()

            // Keyframe operations (current layer only)
            Group {
                Button(action: {
                    let layerId = viewModel.layerViewModel.layers[viewModel.layerViewModel.selectedLayerIndex].id
                    viewModel.toggleKeyframe(frameIndex: viewModel.currentFrameIndex, layerId: layerId)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "diamond")
                        Text("Convert to Keyframe")
                    }
                }
                .help("Convert to Keyframe (F6)")

                Button(action: {
                    let layerId = viewModel.layerViewModel.layers[viewModel.layerViewModel.selectedLayerIndex].id
                    let command = AddKeyframeWithContentCommand(
                        timelineViewModel: viewModel,
                        layerId: layerId
                    )
                    commandManager.performCommand(command)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Keyframe")
                    }
                }
                .help("Add Keyframe with Current Drawing")

                Button(action: {
                    let layerId = viewModel.layerViewModel.layers[viewModel.layerViewModel.selectedLayerIndex].id
                    let command = AddBlankKeyframeCommand(
                        timelineViewModel: viewModel,
                        layerId: layerId,
                        canvasWidth: viewModel.canvasWidth,
                        canvasHeight: viewModel.canvasHeight
                    )
                    commandManager.performCommand(command)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "circle")
                        Text("Add Blank Keyframe")
                    }
                }
                .help("Add Blank Keyframe at Next Position (F7)")

                Button(action: {
                    let layerId = viewModel.layerViewModel.layers[viewModel.layerViewModel.selectedLayerIndex].id
                    let command = ExtendFrameCommand(
                        timelineViewModel: viewModel,
                        frameIndex: viewModel.currentFrameIndex,
                        layerId: layerId
                    )
                    commandManager.performCommand(command)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle")
                        Text("Add Frame")
                    }
                }
                .help("Add Frame (Extend Current Keyframe Span) (F5)")

                Button(action: {
                    if viewModel.totalFrames > 1 {
                        let command = DeleteFrameCommand(timelineViewModel: viewModel, index: viewModel.currentFrameIndex)
                        commandManager.performCommand(command)
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("Delete Frame")
                    }
                }
                .disabled(viewModel.totalFrames <= 1)
                .help("Delete Frame")
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Cell Thumbnail View

struct CellThumbnailView: View {
    let pixels: [[Color?]]
    let size: CGFloat

    var body: some View {
        if let image = renderThumbnail() {
            Image(nsImage: image)
                .resizable()
                .interpolation(.none)
                .frame(width: size, height: size)
        }
    }

    private func renderThumbnail() -> NSImage? {
        guard !pixels.isEmpty, !pixels[0].isEmpty else { return nil }

        let height = pixels.count
        let width = pixels[0].count

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()

        for y in 0..<height {
            for x in 0..<width {
                if let color = pixels[y][x] {
                    NSColor(color).setFill()
                    let rect = NSRect(x: x, y: height - y - 1, width: 1, height: 1)
                    NSBezierPath(rect: rect).fill()
                }
            }
        }

        image.unlockFocus()
        return image
    }
}

// MARK: - Empty Frame View

struct EmptyFrameView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                // 점선 X 표시
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.move(to: CGPoint(x: geometry.size.width, y: 0))
                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
            }
            .stroke(Color.secondary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
        }
    }
}

// MARK: - Layer Drop Delegate

struct LayerDropDelegate: DropDelegate {
    let layerIndex: Int
    @Binding var draggingLayerIndex: Int?
    let viewModel: LayerViewModel
    let commandManager: CommandManager

    func performDrop(info: DropInfo) -> Bool {
        guard let draggingIndex = draggingLayerIndex else { return false }

        if draggingIndex != layerIndex {
            // Calculate destination index
            // If dragging down (from lower index to higher), destination is layerIndex + 1
            // If dragging up (from higher index to lower), destination is layerIndex
            let destination = draggingIndex < layerIndex ? layerIndex + 1 : layerIndex

            let command = MoveLayerCommand(
                layerViewModel: viewModel,
                from: IndexSet(integer: draggingIndex),
                to: destination
            )
            commandManager.performCommand(command)
        }

        draggingLayerIndex = nil
        return true
    }

    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback when hovering over a drop target
    }

    func dropExited(info: DropInfo) {
        // Optional: Remove visual feedback when leaving a drop target
    }
}

// MARK: - Shape Helpers

/// Type-erased Shape wrapper
struct AnyShape: Shape {
    private let _path: (CGRect) -> Path

    init<S: Shape>(_ shape: S) {
        _path = { rect in
            shape.path(in: rect)
        }
    }

    func path(in rect: CGRect) -> Path {
        _path(rect)
    }
}

/// Diamond shape for keyframe markers (Final Cut Pro style)
struct Diamond: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let halfWidth = rect.width / 2
        let halfHeight = rect.height / 2

        // 다이아몬드 4개 꼭지점
        path.move(to: CGPoint(x: center.x, y: center.y - halfHeight)) // 위
        path.addLine(to: CGPoint(x: center.x + halfWidth, y: center.y)) // 오른쪽
        path.addLine(to: CGPoint(x: center.x, y: center.y + halfHeight)) // 아래
        path.addLine(to: CGPoint(x: center.x - halfWidth, y: center.y)) // 왼쪽
        path.closeSubpath()

        return path
    }
}

/// Triangle shape for playhead (Final Cut Pro style)
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        // 아래를 향한 삼각형 (재생 헤드)
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY)) // 아래 중앙
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY)) // 왼쪽 위
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY)) // 오른쪽 위
        path.closeSubpath()

        return path
    }
}

