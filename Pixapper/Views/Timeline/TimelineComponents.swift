//
//  TimelineComponents.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI
import UniformTypeIdentifiers

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
            .padding(.vertical, 6)
            .frame(minWidth: 44, minHeight: 28)
            .foregroundColor(isOn ? Constants.Theme.accentBlue : Constants.Theme.textSecondary)
            .contentShape(Rectangle())
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
    let pixels: PixelGrid
    let size: CGFloat
    let palette: ColorPalette

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
                let pixelValue = pixels[y][x]
                if pixelValue != .transparent {
                    // Convert PixelValue to Color
                    let color: Color
                    switch pixelValue {
                    case .transparent:
                        continue
                    case .indexed(let colorIndex):
                        color = palette.getColor(at: colorIndex) ?? .clear
                    case .gradient:
                        color = .clear
                    }

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

// MARK: - Frame Header Cell with Hover

struct FrameHeaderCellView: View {
    let frameIndex: Int
    let isCurrent: Bool
    let cellSize: CGFloat
    @Binding var dragStartFrameIndex: Int?
    let viewModel: TimelineViewModel
    let calculateFrameIndex: (CGPoint) -> Int

    @State private var isHovered = false

    var body: some View {
        Text("\(frameIndex + 1)")
            .font(.system(size: 9, design: .monospaced))
            .fontWeight(isCurrent ? .bold : .regular)
            .foregroundColor(isCurrent ? Constants.Theme.textPrimary : Constants.Theme.textSecondary)
            .frame(width: cellSize, height: Constants.Layout.Timeline.rowHeight)
            .background(
                isCurrent ? Constants.Theme.accentBlue.opacity(0.2) :
                    (isHovered ? Constants.Theme.hoverBackground : Constants.Theme.sectionBackground)
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
            }
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        if dragStartFrameIndex == nil {
                            dragStartFrameIndex = frameIndex
                            viewModel.selectionAnchor = frameIndex
                        }

                        if let startIndex = dragStartFrameIndex {
                            let currentHoverIndex = calculateFrameIndex(value.location)
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
}

// MARK: - Timeline Toolbar Button with Hover

struct TimelineToolbarButton: View {
    let icon: String
    let text: String
    let tooltip: String
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(text)
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minWidth: 44, minHeight: 28)
            .foregroundColor(disabled ? Constants.Theme.textDisabled : Constants.Theme.textPrimary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 2)
                .fill(disabled ? Constants.Theme.panelBackground :
                      (isHovered ? Constants.Theme.hoverBackground : Constants.Theme.sectionBackground))
        )
        .disabled(disabled)
        .help(tooltip)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
