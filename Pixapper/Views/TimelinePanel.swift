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
    @State private var editingOpacityLayerIndex: Int?  // Opacity 편집 중인 레이어
    @State private var opacityBeforeDrag: Double?  // Opacity 드래그 전 값
    @State private var currentOpacity: Double = 1.0  // 현재 드래그 중인 opacity 값
    @State private var isDraggingFrames: Bool = false  // 프레임 드래그 중인지 판단
    @State private var clickModifierFlags: NSEvent.ModifierFlags = []  // 클릭 시점의 modifier 키

    private let layerColumnWidth: CGFloat = Constants.Layout.Timeline.layerColumnWidth
    private let cellSize: CGFloat = Constants.Layout.Timeline.cellSize

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Playback controls
            PlaybackControlsView(viewModel: viewModel)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Operations toolbar
            TimelineToolbarView(viewModel: viewModel, commandManager: commandManager)

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

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
                    .overlay(
                        // 현재 프레임 세로선 (전체 타임라인 관통)
                        GeometryReader { contentGeometry in
                            let lineX = layerColumnWidth + CGFloat(viewModel.currentFrameIndex) * cellSize
                            Rectangle()
                                .fill(Constants.Theme.playheadRed)
                                .frame(width: 2)
                                .offset(x: lineX, y: Constants.Layout.Timeline.rowHeight)
                        }
                    )
                }
            }
        }
        .background(Constants.Theme.panelBackground)
    }

    // MARK: - Frame Header Row

    private var frameHeaderRow: some View {
        HStack(spacing: 0) {
            // Layer column header
            Text("LAYERS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: layerColumnWidth, height: Constants.Layout.Timeline.rowHeight)
                .background(Constants.Theme.sectionBackground)

            // Frame numbers with drag selection support
            ForEach(viewModel.frames) { frame in
                frameHeaderCell(frameIndex: frame.index)
            }
        }
        .background(Constants.Theme.sectionBackground)
    }

    private func frameHeaderCell(frameIndex: Int) -> some View {
        FrameHeaderCellView(
            frameIndex: frameIndex,
            isCurrent: frameIndex == viewModel.currentFrameIndex,
            cellSize: cellSize,
            dragStartFrameIndex: $dragStartFrameIndex,
            viewModel: viewModel,
            calculateFrameIndex: calculateFrameIndex
        )
    }

    // 마우스 위치로부터 프레임 인덱스 계산
    private func calculateFrameIndex(from location: CGPoint) -> Int {
        return max(0, min(Int(location.x / cellSize), viewModel.totalFrames - 1))
    }

    // MARK: - Layer Row

    private func layerRow(layer: Layer, layerIndex: Int) -> some View {
        HStack(spacing: 0) {
            // Layer info column
            TimelineLayerInfoView(
                layer: layer,
                layerIndex: layerIndex,
                layerColumnWidth: layerColumnWidth,
                cellSize: cellSize,
                viewModel: viewModel,
                commandManager: commandManager,
                editingLayerIndex: $editingLayerIndex,
                editingLayerName: $editingLayerName,
                editingOpacityLayerIndex: $editingOpacityLayerIndex,
                opacityBeforeDrag: $opacityBeforeDrag,
                currentOpacity: $currentOpacity,
                draggingLayerIndex: $draggingLayerIndex
            )

            // Frame cells for this layer - viewModel.frames와 동기화
            ForEach(viewModel.frames) { frame in
                cellView(
                    layer: layer,
                    layerIndex: layerIndex,
                    frameIndex: frame.index
                )
            }
        }
    }

    // MARK: - Cell View

    private func cellView(layer: Layer, layerIndex: Int, frameIndex: Int) -> some View {
        let isSelected = frameIndex == viewModel.currentFrameIndex && layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let isCurrentFrame = frameIndex == viewModel.currentFrameIndex
        let isMultiSelected = viewModel.selectedFrameIndices.contains(frameIndex)
        let spanPosition = viewModel.getFrameSpanPosition(frameIndex: frameIndex, layerId: layer.id)
        let hasContent = viewModel.hasFrameContent(frameIndex: frameIndex, layerId: layer.id)

        return FrameCellView(
            frameIndex: frameIndex,
            layerIndex: layerIndex,
            layerId: layer.id,
            isSelected: isSelected,
            isMultiSelected: isMultiSelected,
            isCurrentFrame: isCurrentFrame,
            spanPosition: spanPosition,
            hasContent: hasContent,
            viewModel: viewModel,
            pixelStateManager: viewModel.pixelStateManager
        )
        .frame(width: cellSize, height: cellSize)
        .contextMenu {
            contextMenuContent(layer: layer, frameIndex: frameIndex, spanPosition: spanPosition)
        }
    }

    // MARK: - Old Cell View (백업용 - 나중에 삭제)

    private func cellViewOld(layer: Layer, layerIndex: Int, frameIndex: Int) -> some View {
        let isSelected = frameIndex == viewModel.currentFrameIndex && layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let isCurrentFrame = frameIndex == viewModel.currentFrameIndex
        let isCurrentLayer = layerIndex == viewModel.layerViewModel.selectedLayerIndex
        let isMultiSelected = viewModel.selectedFrameIndices.contains(frameIndex)
        let effectivePixels = viewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layer.id)
        let spanPosition = viewModel.getFrameSpanPosition(frameIndex: frameIndex, layerId: layer.id)
        let hasContent = viewModel.hasFrameContent(frameIndex: frameIndex, layerId: layer.id)
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
        .help(makeTooltipText(layer: layer, frameIndex: frameIndex, spanPosition: spanPosition, isOutOfRange: isOutOfRange))
        .contentShape(Rectangle())
        .opacity(isOutOfRange ? 0.4 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    let distance = hypot(value.translation.width, value.translation.height)

                    if dragStartFrameIndex == nil {
                        // 첫 호출: modifier 키 캡처
                        if let event = NSApp.currentEvent {
                            clickModifierFlags = event.modifierFlags
                        }

                        dragStartFrameIndex = frameIndex
                        isDraggingFrames = false
                        viewModel.selectionAnchor = frameIndex
                        viewModel.layerViewModel.selectedLayerIndex = layerIndex
                    }

                    // 5pt 이상 움직이면 드래그로 간주
                    if distance > 5 {
                        isDraggingFrames = true

                        // 범위 선택
                        if let startIndex = dragStartFrameIndex {
                            let range = min(startIndex, frameIndex)...max(startIndex, frameIndex)
                            viewModel.selectedFrameIndices = Set(range.filter { $0 < viewModel.totalFrames })
                        }
                    }
                }
                .onEnded { value in
                    if !isDraggingFrames {
                        // 클릭으로 처리 - 저장된 modifier 사용
                        handleFrameClickWithModifiers(
                            frameIndex: frameIndex,
                            layerIndex: layerIndex,
                            modifiers: clickModifierFlags
                        )
                    }

                    // 리셋
                    dragStartFrameIndex = nil
                    isDraggingFrames = false
                    clickModifierFlags = []
                }
        )
        .onHover { hovering in
            // 드래그 중일 때만 범위 확장
            if hovering, isDraggingFrames, let startIndex = dragStartFrameIndex {
                let range = min(startIndex, frameIndex)...max(startIndex, frameIndex)
                viewModel.selectedFrameIndices = Set(range.filter { $0 < viewModel.totalFrames })
            }
        }
        .onDrag {
            // 드래그 시작: 선택된 프레임 정보를 전달
            let dragData = "\(layer.id.uuidString):\(frameIndex)"
            return NSItemProvider(object: dragData as NSString)
        }
        .onDrop(of: [.text], isTargeted: nil) { providers, location in
            // 드롭 처리: 프레임 이동
            guard let provider = providers.first else { return false }

            provider.loadObject(ofClass: NSString.self) { object, error in
                guard let dragData = object as? String,
                      let parts = dragData.components(separatedBy: ":") as [String]?,
                      parts.count == 2,
                      let sourceLayerIdString = parts.first,
                      let sourceLayerId = UUID(uuidString: sourceLayerIdString),
                      let sourceFrameIndex = Int(parts.last ?? "") else {
                    return
                }

                // 같은 레이어 내에서만 이동 가능
                guard sourceLayerId == layer.id else { return }

                DispatchQueue.main.async {
                    // 프레임 이동 처리
                    moveFrame(from: sourceFrameIndex, to: frameIndex, layerId: layer.id)
                }
            }

            return true
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
        let isMultipleSelection = viewModel.selectedFrameIndices.count > 1

        // Copy/Cut/Paste operations
        Button("Copy") {
            viewModel.copyFrames(frameIndices: viewModel.selectedFrameIndices, layerId: layer.id)
        }
        .keyboardShortcut("c", modifiers: .command)
        .disabled(viewModel.selectedFrameIndices.isEmpty)

        Button("Cut") {
            viewModel.cutFrames(frameIndices: viewModel.selectedFrameIndices, layerId: layer.id)
        }
        .keyboardShortcut("x", modifiers: .command)
        .disabled(viewModel.selectedFrameIndices.isEmpty)

        Button("Paste") {
            viewModel.pasteFrames(at: frameIndex, layerId: layer.id)
        }
        .keyboardShortcut("v", modifiers: .command)
        .disabled(!viewModel.hasFrameClipboard || isMultipleSelection)

        Divider()

        // Convert to Keyframe (K) - 단일 선택만 허용
        Button("Convert to Keyframe (K)") {
            viewModel.toggleKeyframe(frameIndex: frameIndex, layerId: layer.id)
        }
        .disabled(isMultipleSelection)

        // Add Keyframe with Current Drawing (I) - 단일 선택만 허용
        Button("Add Keyframe with Current Drawing (I)") {
            let command = AddKeyframeWithContentCommand(
                timelineViewModel: viewModel,
                layerId: layer.id
            )
            commandManager.performCommand(command)
        }
        .disabled(isMultipleSelection)

        // Add Blank Keyframe (B) - 단일 선택만 허용
        Button("Add Blank Keyframe (B)") {
            let command = AddBlankKeyframeCommand(
                timelineViewModel: viewModel,
                layerId: layer.id,
                canvasWidth: viewModel.canvasWidth,
                canvasHeight: viewModel.canvasHeight
            )
            commandManager.performCommand(command)
        }
        .disabled(isMultipleSelection)

        Divider()

        // Add Frame (Extend) (E) - 단일 선택만 허용
        Button("Extend Frame (E)") {
            let command = ExtendFrameCommand(
                timelineViewModel: viewModel,
                frameIndex: frameIndex,
                layerId: layer.id
            )
            commandManager.performCommand(command)
        }
        .disabled(isMultipleSelection)

        // Delete Frame - 복수 선택 허용
        Button("Delete Frame", role: .destructive) {
            let command = DeleteFrameInLayerCommand(
                timelineViewModel: viewModel,
                index: frameIndex,
                layerId: layer.id
            )
            commandManager.performCommand(command)
        }
    }

    // MARK: - Cell Components

    @ViewBuilder
    private func cellBackground(spanPosition: TimelineViewModel.FrameSpanPosition, isSelected: Bool, isMultiSelected: Bool, isCurrentFrame: Bool, isCurrentLayer: Bool, isOutOfRange: Bool) -> some View {
        let backgroundColor: Color = {
            // Out of range: 매우 연한 회색
            if isOutOfRange {
                return Color(nsColor: .controlBackgroundColor).opacity(0.5)
            }

            // 복수 선택된 프레임: 파란색 하이라이트
            if isMultiSelected {
                return Color.accentColor.opacity(0.3)
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

        Rectangle()
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
                        // Extended 프레임: 작은 점으로 span 연속성 표시
                        if hasContent {
                            Circle()
                                .fill(Color(nsColor: .secondaryLabelColor))
                                .frame(width: 3, height: 3)
                        } else {
                            EmptyView()
                        }
                    case .end:
                        // Span 끝: 작은 수직선으로 span 종료 표시
                        if hasContent {
                            Rectangle()
                                .fill(Color(nsColor: .tertiaryLabelColor))
                                .frame(width: 1.5, height: 6)
                        } else {
                            EmptyView()
                        }
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
            // 현재 프레임 (현재 레이어): 두꺼운 accentColor 테두리
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 2)
        } else if isMultiSelected {
            // 복수 선택된 프레임: 얇은 accentColor 테두리
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 1.5)
        }
    }

    // MARK: - Helper Functions

    /// 프레임 이동 (드래그 앤 드롭)
    private func moveFrame(from sourceIndex: Int, to targetIndex: Int, layerId: UUID) {
        guard sourceIndex != targetIndex,
              let layerIndex = viewModel.layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        var layer = viewModel.layerViewModel.layers[layerIndex]

        // 소스와 타겟이 모두 키프레임인 경우에만 이동 가능
        guard layer.timeline.isKeyframe(at: sourceIndex),
              layer.timeline.isKeyframe(at: targetIndex) else {
            return
        }

        // 두 키프레임의 픽셀 데이터 교환
        if let sourcePixels = layer.timeline.getKeyframe(at: sourceIndex),
           let targetPixels = layer.timeline.getKeyframe(at: targetIndex) {
            layer.timeline.setKeyframe(at: sourceIndex, pixels: targetPixels)
            layer.timeline.setKeyframe(at: targetIndex, pixels: sourcePixels)

            viewModel.layerViewModel.layers[layerIndex] = layer
            viewModel.loadFrame(at: viewModel.currentFrameIndex)
        }
    }

    /// 프레임 클릭 처리 (저장된 modifier 사용)
    private func handleFrameClickWithModifiers(frameIndex: Int, layerIndex: Int, modifiers: NSEvent.ModifierFlags) {
        if modifiers.contains(.command) {
            // Cmd+Click: 개별 선택/해제 (토글)
            if viewModel.selectedFrameIndices.contains(frameIndex) {
                viewModel.selectedFrameIndices.remove(frameIndex)
                if viewModel.selectedFrameIndices.isEmpty {
                    viewModel.selectionAnchor = nil
                }
            } else {
                viewModel.selectedFrameIndices.insert(frameIndex)
                viewModel.selectionAnchor = frameIndex
            }
        } else if modifiers.contains(.shift) {
            // Shift+Click: 범위 선택
            if let anchor = viewModel.selectionAnchor {
                let range = min(anchor, frameIndex)...max(anchor, frameIndex)
                viewModel.selectedFrameIndices = Set(range.filter { $0 < viewModel.totalFrames })
            } else {
                // 앵커가 없으면 단일 선택
                viewModel.selectedFrameIndices = [frameIndex]
                viewModel.selectionAnchor = frameIndex
            }
        } else {
            // 일반 클릭: 단일 선택
            viewModel.selectFrame(at: frameIndex)
            viewModel.selectedFrameIndices = [frameIndex]
            viewModel.selectionAnchor = frameIndex
        }

        // 레이어 선택
        viewModel.layerViewModel.selectedLayerIndex = layerIndex
    }

    /// 프레임 클릭 처리 (레거시 - 호환성)
    private func handleFrameClick(frameIndex: Int, layerIndex: Int) {
        guard let event = NSApp.currentEvent else {
            viewModel.selectFrame(at: frameIndex)
            viewModel.selectedFrameIndices = [frameIndex]
            viewModel.selectionAnchor = frameIndex
            viewModel.layerViewModel.selectedLayerIndex = layerIndex
            return
        }

        handleFrameClickWithModifiers(frameIndex: frameIndex, layerIndex: layerIndex, modifiers: event.modifierFlags)
    }

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
}

