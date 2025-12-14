//
//  FrameCellView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 순수 SwiftUI 프레임 셀 - 완전 Reactive
struct FrameCellView: View {
    let frameIndex: Int
    let layerIndex: Int
    let layerId: UUID
    let isSelected: Bool
    let isMultiSelected: Bool
    let isCurrentFrame: Bool
    let spanPosition: TimelineViewModel.FrameSpanPosition
    let hasContent: Bool

    @ObservedObject var viewModel: TimelineViewModel
    @ObservedObject var pixelStateManager: PixelStateManager

    @State private var dragStartIndex: Int?

    var body: some View {
        ZStack {
            // 배경색
            backgroundColor
                .cornerRadius(2)

            // 썸네일
            if spanPosition == .keyframeStart && hasContent {
                thumbnailView
                    .padding(3)
            }

            // 키프레임 인디케이터
            keyframeIndicator
        }
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(borderColor, lineWidth: isSelected ? 2 : 0)
        )
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .simultaneousGesture(clickGesture)
    }

    // MARK: - UI Components

    private var backgroundColor: Color {
        switch spanPosition {
        case .keyframeStart:
            return Color(nsColor: .separatorColor).opacity(0.6)
        case .extended, .end:
            return Color(nsColor: .separatorColor).opacity(0.2)
        case .empty:
            return Color(nsColor: .controlBackgroundColor)
        }
    }

    private var borderColor: Color {
        isSelected ? .red : .clear
    }

    private var thumbnailView: some View {
        GeometryReader { geometry in
            if let thumbnail = generateThumbnail() {
                ZStack {
                    // 체크보드 배경
                    checkerboardBackground
                    // 썸네일 이미지
                    Image(nsImage: thumbnail)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                }
                .cornerRadius(1)
            }
        }
    }

    private var checkerboardBackground: some View {
        let checkerboard = createCheckerboardPattern()
        return Color(nsColor: NSColor(patternImage: checkerboard))
    }

    private var keyframeIndicator: some View {
        GeometryReader { geometry in
            switch spanPosition {
            case .keyframeStart, .empty:
                EmptyView()
            case .extended:
                Path { path in
                    // 위아래 가는 선
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                }
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
            case .end:
                Path { path in
                    // 위아래 + 오른쪽
                    path.move(to: CGPoint(x: 0, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                }
                .stroke(Color(nsColor: .separatorColor).opacity(0.3), lineWidth: 0.5)
            }
        }
    }

    // MARK: - Gestures

    private var clickGesture: some Gesture {
        TapGesture()
            .modifiers(.command)
            .onEnded { _ in
                // Cmd+클릭: 토글
                if viewModel.selectedFrameIndices.contains(frameIndex) {
                    viewModel.selectedFrameIndices.remove(frameIndex)
                } else {
                    viewModel.selectedFrameIndices.insert(frameIndex)
                }
                viewModel.selectionAnchor = frameIndex
            }
            .exclusively(before:
                TapGesture()
                    .modifiers(.shift)
                    .onEnded { _ in
                        // Shift+클릭: 범위 선택
                        if let anchor = viewModel.selectionAnchor {
                            let range = min(anchor, frameIndex)...max(anchor, frameIndex)
                            viewModel.selectedFrameIndices = Set(range.filter { $0 < viewModel.totalFrames })
                        } else {
                            viewModel.selectedFrameIndices = [frameIndex]
                            viewModel.selectionAnchor = frameIndex
                        }
                    }
                    .exclusively(before:
                        TapGesture()
                            .onEnded { _ in
                                // 일반 클릭: 단일 선택
                                viewModel.selectFrame(at: frameIndex)
                                viewModel.selectedFrameIndices = [frameIndex]
                                viewModel.selectionAnchor = frameIndex
                                viewModel.layerViewModel.selectedLayerIndex = layerIndex
                            }
                    )
            )
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                if dragStartIndex == nil {
                    dragStartIndex = frameIndex
                }
                // 드래그 범위 선택은 TimelinePanel에서 처리하기 어려우므로 생략
                // 필요하면 좌표 기반으로 계산 가능
            }
            .onEnded { _ in
                dragStartIndex = nil
            }
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail() -> NSImage? {
        // 픽셀 데이터 가져오기
        let pixels: [[Color?]]?
        if frameIndex == pixelStateManager.currentFrameIndex {
            pixels = pixelStateManager.currentFramePixels[layerId]
        } else {
            pixels = viewModel.getEffectivePixels(frameIndex: frameIndex, layerId: layerId)
        }

        guard let pixels = pixels, !pixels.isEmpty else { return nil }

        let height = pixels.count
        guard height > 0 else { return nil }
        let width = pixels[0].count
        guard width > 0 else { return nil }

        let size = NSSize(width: width, height: height)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        // 픽셀 렌더링
        for y in 0..<height {
            for x in 0..<width {
                if let color = pixels[y][x] {
                    NSColor(color).setFill()
                    NSRect(x: x, y: height - 1 - y, width: 1, height: 1).fill()
                }
            }
        }

        return image
    }

    private func createCheckerboardPattern() -> NSImage {
        let lightGray = NSColor.lightGray.withAlphaComponent(0.15)
        let darkGray = NSColor.darkGray.withAlphaComponent(0.15)

        let patternSize: CGFloat = 4
        let image = NSImage(size: NSSize(width: patternSize * 2, height: patternSize * 2))

        image.lockFocus()
        lightGray.setFill()
        NSRect(x: 0, y: 0, width: patternSize, height: patternSize).fill()
        NSRect(x: patternSize, y: patternSize, width: patternSize, height: patternSize).fill()
        darkGray.setFill()
        NSRect(x: patternSize, y: 0, width: patternSize, height: patternSize).fill()
        NSRect(x: 0, y: patternSize, width: patternSize, height: patternSize).fill()
        image.unlockFocus()

        return image
    }
}
