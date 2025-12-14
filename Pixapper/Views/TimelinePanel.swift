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
            playbackControls

            Rectangle()
                .fill(Constants.Theme.divider)
                .frame(height: 1)

            // Operations toolbar
            operationsToolbar

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
                                .offset(x: lineX, y: Constants.Layout.Timeline.frameHeaderHeight)
                        }
                    )
                }
            }
        }
        .background(Constants.Theme.panelBackground)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        HStack(spacing: 8) {
            // Left: Playback & Navigation
            HStack(spacing: 2) {
                TimelineButton(icon: viewModel.isPlaying ? "pause.fill" : "play.fill", size: 24, tooltip: "Play/Pause (Space)") {
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
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Constants.Theme.sectionBackground)
    }

    // MARK: - Frame Header Row

    private var frameHeaderRow: some View {
        HStack(spacing: 0) {
            // Layer column header
            Text("LAYERS")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: layerColumnWidth, height: 26)
                .background(Constants.Theme.sectionBackground)

            // Frame numbers with drag selection support
            ForEach(viewModel.frames) { frame in
                frameHeaderCell(frameIndex: frame.index)
            }
        }
        .background(Constants.Theme.sectionBackground)
    }

    private func frameHeaderCell(frameIndex: Int) -> some View {
        let isCurrent = frameIndex == viewModel.currentFrameIndex

        return Text("\(frameIndex + 1)")
            .font(.system(size: 9, design: .monospaced))
            .fontWeight(isCurrent ? .bold : .regular)
            .foregroundColor(isCurrent ? Constants.Theme.textPrimary : Constants.Theme.textSecondary)
            .frame(width: cellSize, height: 26)
            .background(isCurrent ? Constants.Theme.hoverBackground : Constants.Theme.sectionBackground)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if dragStartFrameIndex == nil {
                            dragStartFrameIndex = frameIndex
                            viewModel.selectionAnchor = frameIndex
                        }

                        if let startIndex = dragStartFrameIndex {
                            let currentHoverIndex = calculateFrameIndex(from: value.location)
                            viewModel.updateDragSelection(from: startIndex, to: currentHoverIndex)
                        }
                    }
                    .onEnded { _ in
                        dragStartFrameIndex = nil

                        if let lastSelected = viewModel.selectedFrameIndices.max() {
                            viewModel.selectFrame(at: lastSelected, clearSelection: false)
                        }
                    }
            )
            .simultaneousGesture(
                TapGesture().onEnded {
                    viewModel.selectSingleFrame(at: frameIndex)
                }
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
            layerInfoColumn(layer: layer, layerIndex: layerIndex)

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

    // MARK: - Layer Info Column

    private func layerInfoColumn(layer: Layer, layerIndex: Int) -> some View {
        HStack(spacing: 4) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundColor(Constants.Theme.textSecondary)
                .frame(width: 14)

            // Visibility toggle
            Button(action: {
                viewModel.layerViewModel.toggleVisibility(at: layerIndex)
            }) {
                Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                    .font(.system(size: 10))
                    .frame(width: 18, height: 18)
                    .foregroundColor(layer.isVisible ? Constants.Theme.textPrimary : Constants.Theme.textDisabled)
            }
            .buttonStyle(.plain)

            // Layer name and opacity
            VStack(alignment: .leading, spacing: 2) {
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Constants.Theme.textPrimary)
                } else {
                    Text(layer.name)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Constants.Theme.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .onTapGesture(count: 2) {
                            editingLayerIndex = layerIndex
                            editingLayerName = layer.name
                        }
                }

                // Opacity control
                HStack(spacing: 4) {
                    if editingOpacityLayerIndex == layerIndex {
                        // Editing mode: Show slider
                        Slider(
                            value: $currentOpacity,
                            in: 0...1,
                            onEditingChanged: { isEditing in
                                if isEditing {
                                    opacityBeforeDrag = viewModel.layerViewModel.layers[layerIndex].opacity
                                    currentOpacity = viewModel.layerViewModel.layers[layerIndex].opacity
                                } else {
                                    if let oldOpacity = opacityBeforeDrag {
                                        if abs(oldOpacity - currentOpacity) > 0.001 {
                                            let command = SetLayerOpacityCommand(
                                                layerViewModel: viewModel.layerViewModel,
                                                index: layerIndex,
                                                oldOpacity: oldOpacity,
                                                newOpacity: currentOpacity
                                            )
                                            commandManager.addExecutedCommand(command)
                                        }
                                        opacityBeforeDrag = nil
                                    }
                                    editingOpacityLayerIndex = nil
                                }
                            }
                        )
                        .controlSize(.mini)
                        .onChange(of: currentOpacity) { _, newValue in
                            viewModel.layerViewModel.setOpacity(at: layerIndex, opacity: newValue)
                        }
                    }

                    // Percentage display (always visible, clickable)
                    Text("\(Int((editingOpacityLayerIndex == layerIndex ? currentOpacity : viewModel.layerViewModel.layers[layerIndex].opacity) * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(editingOpacityLayerIndex == layerIndex ? Constants.Theme.accentBlue : Constants.Theme.textSecondary)
                        .underline(editingOpacityLayerIndex != layerIndex, color: Constants.Theme.textSecondary.opacity(0.3))
                        .frame(width: 30, alignment: .trailing)
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            if hovering && editingOpacityLayerIndex != layerIndex {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        .onTapGesture {
                            if editingOpacityLayerIndex == layerIndex {
                                editingOpacityLayerIndex = nil
                            } else {
                                currentOpacity = viewModel.layerViewModel.layers[layerIndex].opacity
                                editingOpacityLayerIndex = layerIndex
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .frame(width: layerColumnWidth, height: cellSize)
        .background(
            Group {
                if layerIndex == viewModel.layerViewModel.selectedLayerIndex {
                    Constants.Theme.accentBlue.opacity(0.2)
                } else if draggingLayerIndex == layerIndex {
                    Constants.Theme.accentBlue.opacity(0.3)
                } else {
                    Constants.Theme.panelBackground
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
        .disabled(viewModel.selectedFrameIndices.isEmpty)

        Button("Cut") {
            viewModel.cutFrames(frameIndices: viewModel.selectedFrameIndices, layerId: layer.id)
        }
        .disabled(viewModel.selectedFrameIndices.isEmpty)

        Button("Paste") {
            viewModel.pasteFrames(at: frameIndex, layerId: layer.id)
        }
        .disabled(!viewModel.hasFrameClipboard || isMultipleSelection)

        Divider()

        // Convert to Keyframe (F6) - 단일 선택만 허용
        Button("Convert to Keyframe") {
            viewModel.toggleKeyframe(frameIndex: frameIndex, layerId: layer.id)
        }
        .disabled(isMultipleSelection)

        // Add Keyframe with Current Drawing - 단일 선택만 허용
        Button("Add Keyframe with Current Drawing") {
            let command = AddKeyframeWithContentCommand(
                timelineViewModel: viewModel,
                layerId: layer.id
            )
            commandManager.performCommand(command)
        }
        .disabled(isMultipleSelection)

        // Add Blank Keyframe (F7) - 단일 선택만 허용
        Button("Add Blank Keyframe") {
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

        // Add Frame (Extend) (F5) - 단일 선택만 허용
        Button("Extend Frame") {
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

    // MARK: - Operations Toolbar

    private var operationsToolbar: some View {
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
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
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

            HStack(spacing: 2) {
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
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(text)
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .foregroundColor(disabled ? Constants.Theme.textDisabled : Constants.Theme.textPrimary)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(disabled ? Constants.Theme.panelBackground : Constants.Theme.hoverBackground)
        )
        .disabled(disabled)
        .help(tooltip)
    }
}

// MARK: - Timeline UI Components

struct TimelineButton: View {
    let icon: String
    let size: CGFloat
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .frame(width: 28, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundColor(Constants.Theme.textPrimary)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(isHovered ? Constants.Theme.hoverBackground : Color.clear)
        )
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct TimelineToggleButton: View {
    let icon: String
    let text: String
    let isOn: Bool
    let tooltip: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(text)
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundColor(isOn ? Constants.Theme.accentBlue : Constants.Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(isOn ? Constants.Theme.accentBlue.opacity(0.15) : (isHovered ? Constants.Theme.hoverBackground : Constants.Theme.panelBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(isOn ? Constants.Theme.accentBlue.opacity(0.5) : Color.clear, lineWidth: 1)
        )
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
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
    private let _path: @Sendable (CGRect) -> Path

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

