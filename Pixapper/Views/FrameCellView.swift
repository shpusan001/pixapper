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

    var body: some View {
        ZStack {
            // 배경색
            backgroundColor
                .cornerRadius(1)

            // 썸네일
            if spanPosition == .keyframeStart && hasContent {
                thumbnailView
                    .padding(4)
            }

            // 키프레임 인디케이터
            keyframeIndicator

            // 클릭 처리용 투명 오버레이
            ClickHandlerView(
                frameIndex: frameIndex,
                layerIndex: layerIndex,
                viewModel: viewModel
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 1)
                .strokeBorder(borderColor, lineWidth: (isSelected || isMultiSelected) ? 2 : 0)
        )
    }

    // MARK: - UI Components

    private var backgroundColor: Color {
        switch spanPosition {
        case .keyframeStart:
            return Constants.Theme.sectionBackground
        case .extended, .end:
            return Constants.Theme.sectionBackground.opacity(0.5)
        case .empty:
            return Constants.Theme.backgroundDark
        }
    }

    private var borderColor: Color {
        if isSelected || isMultiSelected {
            return Constants.Theme.accentBlue
        } else {
            return Color.clear
        }
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

// MARK: - Click Handler (NSView로 Cmd/Shift 감지)

struct ClickHandlerView: NSViewRepresentable {
    let frameIndex: Int
    let layerIndex: Int
    let viewModel: TimelineViewModel

    func makeNSView(context: Context) -> ClickHandlerNSView {
        let view = ClickHandlerNSView()
        view.frameIndex = frameIndex
        view.layerIndex = layerIndex
        view.viewModel = viewModel
        return view
    }

    func updateNSView(_ nsView: ClickHandlerNSView, context: Context) {
        nsView.frameIndex = frameIndex
        nsView.layerIndex = layerIndex
        nsView.viewModel = viewModel
    }
}

class ClickHandlerNSView: NSView {
    var frameIndex: Int = 0
    var layerIndex: Int = 0
    weak var viewModel: TimelineViewModel?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 투명하게
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func mouseDown(with event: NSEvent) {
        Task { @MainActor in
            guard let vm = viewModel else { return }

            let modifiers = event.modifierFlags

            if modifiers.contains(.command) {
                // Cmd+클릭: 토글 선택
                if vm.selectedFrameIndices.contains(frameIndex) {
                    vm.selectedFrameIndices.remove(frameIndex)
                    if vm.selectedFrameIndices.isEmpty {
                        vm.selectionAnchor = nil
                    }
                } else {
                    vm.selectedFrameIndices.insert(frameIndex)
                    vm.selectionAnchor = frameIndex
                    vm.currentFrameIndex = frameIndex
                    vm.loadFrame(at: frameIndex)
                }
            } else if modifiers.contains(.shift) {
                // Shift+클릭: 범위 선택
                let anchor = vm.selectionAnchor ?? vm.currentFrameIndex
                let range = min(anchor, frameIndex)...max(anchor, frameIndex)
                vm.selectedFrameIndices = Set(range.filter { $0 < vm.totalFrames })
                vm.currentFrameIndex = frameIndex
                vm.loadFrame(at: frameIndex)
            } else {
                // 일반 클릭: 단일 선택
                vm.selectedFrameIndices = [frameIndex]
                vm.selectionAnchor = frameIndex
                vm.selectFrame(at: frameIndex)
            }

            vm.layerViewModel.selectedLayerIndex = layerIndex
        }
    }
}
