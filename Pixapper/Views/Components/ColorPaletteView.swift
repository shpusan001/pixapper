//
//  ColorPaletteView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-15.
//

import SwiftUI

/// 프로젝트 색상 팔레트를 표시하고 관리하는 컴포넌트
struct ColorPaletteView: View {
    @ObservedObject var colorManager: ColorManager

    @State private var editingColorIndex: Int?
    @State private var editingColor: Color = .black
    @State private var deleteMode: Bool = false

    private let colorSize: CGFloat = 24
    private let spacing: CGFloat = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text("Palette")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Constants.Theme.textSecondary)

                Spacer()

                HStack(spacing: 4) {
                    // Delete mode toggle
                    Button(action: {
                        deleteMode.toggle()
                    }) {
                        Image(systemName: deleteMode ? "checkmark" : "minus")
                            .font(.system(size: 9))
                            .foregroundColor(deleteMode ? .white : Constants.Theme.textPrimary)
                            .frame(width: 18, height: 18)
                            .background(deleteMode ? Color.red : Constants.Theme.sectionBackground)
                            .cornerRadius(2)
                    }
                    .buttonStyle(.plain)
                    .help(deleteMode ? "Done" : "Remove Colors")
                    .disabled(colorManager.palette.isEmpty)
                    .opacity(colorManager.palette.isEmpty ? 0.3 : 1.0)

                    // Add color button
                    Button(action: {
                        colorManager.palette.append(colorManager.primaryColor)
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 9))
                            .foregroundColor(Constants.Theme.textPrimary)
                            .frame(width: 18, height: 18)
                            .background(Constants.Theme.sectionBackground)
                            .cornerRadius(2)
                    }
                    .buttonStyle(.plain)
                    .help("Add Current Color to Palette")
                }
            }

            // Responsive color grid
            GeometryReader { geometry in
                let availableWidth = geometry.size.width
                let columns = max(1, Int((availableWidth + spacing) / (colorSize + spacing)))
                let rows = colorManager.palette.isEmpty ? 0 : (colorManager.palette.count + columns - 1) / columns

                VStack(alignment: .leading, spacing: spacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        HStack(spacing: spacing) {
                            ForEach(0..<columns, id: \.self) { col in
                                let index = row * columns + col
                                if index < colorManager.palette.count {
                                    PaletteColorCell(
                                        color: colorManager.palette[index],
                                        deleteMode: deleteMode,
                                        onTap: {
                                            if deleteMode {
                                                colorManager.removeFromPalette(at: index)
                                            } else {
                                                colorManager.setPrimaryColor(colorManager.palette[index])
                                            }
                                        },
                                        onRightClick: {
                                            if !deleteMode {
                                                colorManager.setSecondaryColor(colorManager.palette[index])
                                            }
                                        },
                                        onDoubleClick: {
                                            if !deleteMode {
                                                editingColorIndex = index
                                                editingColor = colorManager.palette[index]
                                            }
                                        },
                                        onDelete: {
                                            colorManager.removeFromPalette(at: index)
                                        }
                                    )
                                }
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
            }
            .frame(height: calculateGridHeight())
        }
        .sheet(item: Binding(
            get: { editingColorIndex.map { ColorEditItem(index: $0) } },
            set: { newValue in
                if let newValue = newValue {
                    editingColorIndex = newValue.index
                } else {
                    if let index = editingColorIndex {
                        colorManager.updatePalette(at: index, with: editingColor)
                    }
                    editingColorIndex = nil
                }
            }
        )) { item in
            VStack(spacing: 16) {
                Text("Edit Palette Color")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Constants.Theme.textPrimary)

                ColorPicker("Color", selection: $editingColor, supportsOpacity: true)
                    .labelsHidden()
                    .frame(width: 200)

                HStack(spacing: 8) {
                    Button("Cancel") {
                        editingColorIndex = nil
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Constants.Theme.sectionBackground)
                    .foregroundColor(Constants.Theme.textPrimary)
                    .cornerRadius(2)

                    Button("Done") {
                        colorManager.updatePalette(at: item.index, with: editingColor)
                        editingColorIndex = nil
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Constants.Theme.accentBlue)
                    .foregroundColor(.white)
                    .cornerRadius(2)
                }
            }
            .padding(24)
            .frame(width: 280)
            .background(Constants.Theme.panelBackground)
        }
    }

    private func calculateGridHeight() -> CGFloat {
        let minColumns = 6
        let rows = colorManager.palette.isEmpty ? 1 : (colorManager.palette.count + minColumns - 1) / minColumns
        return CGFloat(rows) * (colorSize + spacing) - spacing
    }
}

struct ColorEditItem: Identifiable {
    let id = UUID()
    let index: Int
}

/// 팔레트 색상 셀
private struct PaletteColorCell: View {
    let color: Color
    let deleteMode: Bool
    let onTap: () -> Void
    let onRightClick: () -> Void
    let onDoubleClick: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var clickCount = 0
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // 체크보드 배경
            checkerboardBackground

            Rectangle()
                .fill(color)

            // Delete mode overlay
            if deleteMode {
                Rectangle()
                    .fill(Color.black.opacity(0.5))

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
        }
        .frame(width: 24, height: 24)
        .cornerRadius(2)
        .overlay(
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(
                    deleteMode ? Color.red : (isHovered ? Constants.Theme.accentBlue : Constants.Theme.divider),
                    lineWidth: deleteMode || isHovered ? 2 : 1
                )
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if deleteMode {
                onTap()
            } else {
                clickCount += 1

                if clickCount == 1 {
                    timer?.invalidate()
                    timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { _ in
                        if clickCount == 1 {
                            onTap()
                        }
                        clickCount = 0
                    }
                } else if clickCount == 2 {
                    timer?.invalidate()
                    onDoubleClick()
                    clickCount = 0
                }
            }
        }
        .simultaneousGesture(
            TapGesture()
                .modifiers(.control)
                .onEnded { _ in
                    timer?.invalidate()
                    clickCount = 0
                    if !deleteMode {
                        onRightClick()
                    }
                }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .contextMenu {
            if !deleteMode {
                Button("Set as Primary") { onTap() }
                Button("Set as Secondary") { onRightClick() }
                Button("Edit Color") { onDoubleClick() }
                Divider()
            }
            Button("Remove from Palette", role: .destructive) { onDelete() }
        }
        .help(deleteMode ? "Click to remove" : "Click: Primary | Ctrl+Click: Secondary | Double-click: Edit")
    }

    private var checkerboardBackground: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let squareSize: CGFloat = 4
                let columns = Int(ceil(size.width / squareSize))
                let rows = Int(ceil(size.height / squareSize))

                for row in 0..<rows {
                    for col in 0..<columns {
                        let isLight = (row + col) % 2 == 0
                        let color = isLight ? Color.white.opacity(0.2) : Color.black.opacity(0.2)
                        let rect = CGRect(
                            x: CGFloat(col) * squareSize,
                            y: CGFloat(row) * squareSize,
                            width: squareSize,
                            height: squareSize
                        )
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
    }
}
