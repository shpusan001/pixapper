//
//  PaletteSelectorView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-19.
//

import SwiftUI
import UniformTypeIdentifiers

/// 팔레트 선택 및 관리 뷰
struct PaletteSelectorView: View {
    @ObservedObject var paletteManager: PaletteManager

    @State private var showingNewPaletteDialog = false
    @State private var newPaletteName = ""
    @State private var showingPresetPicker = false
    @State private var showingImportError = false
    @State private var importErrorMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Palettes")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Constants.Theme.textPrimary)

                Spacer()

                // Actions
                Menu {
                    Button("New Palette") {
                        newPaletteName = "New Palette"
                        showingNewPaletteDialog = true
                    }

                    Button("Load Preset") {
                        showingPresetPicker = true
                    }

                    Button("Duplicate Current") {
                        paletteManager.duplicatePalette(paletteManager.currentPaletteId)
                    }

                    Divider()

                    Button("Import Palette...") {
                        importPalette()
                    }

                    Button("Export Current...") {
                        exportPalette()
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20, height: 20)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Constants.Theme.sectionBackground)

            Divider()

            // Palette List
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(paletteManager.paletteList) { palette in
                        PaletteRow(
                            palette: palette,
                            isSelected: palette.id == paletteManager.currentPaletteId,
                            onSelect: {
                                paletteManager.switchPalette(to: palette.id)
                            },
                            onDelete: {
                                if paletteManager.paletteList.count > 1 {
                                    paletteManager.deletePalette(palette.id)
                                }
                            },
                            onRename: { newName in
                                paletteManager.renamePalette(palette.id, to: newName)
                            }
                        )
                    }
                }
            }
        }
        .background(Constants.Theme.panelBackground)
        .sheet(isPresented: $showingNewPaletteDialog) {
            NewPaletteDialog(paletteName: $newPaletteName, paletteManager: paletteManager)
        }
        .sheet(isPresented: $showingPresetPicker) {
            PresetPickerDialog(paletteManager: paletteManager)
        }
        .alert("Import Error", isPresented: $showingImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: - Import/Export Methods

    private func importPalette() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "gpl")!,
            .init(filenameExtension: "pal")!,
            .init(filenameExtension: "ase")!
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let palette: ColorPalette
                let ext = url.pathExtension.lowercased()

                switch ext {
                case "gpl":
                    palette = try PaletteFileIO.loadGPL(from: url)
                case "pal":
                    palette = try PaletteFileIO.loadPAL(from: url)
                case "ase":
                    palette = try PaletteFileIO.loadASE(from: url)
                default:
                    throw PaletteError.invalidFormat
                }

                paletteManager.addPalette(palette)
                paletteManager.switchPalette(to: palette.id)
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        }
    }

    private func exportPalette() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "gpl")!,
            .init(filenameExtension: "pal")!,
            .init(filenameExtension: "ase")!
        ]
        panel.nameFieldStringValue = paletteManager.currentPalette.name

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let ext = url.pathExtension.lowercased()

                switch ext {
                case "gpl":
                    try PaletteFileIO.saveGPL(palette: paletteManager.currentPalette, to: url)
                case "pal":
                    try PaletteFileIO.savePAL(palette: paletteManager.currentPalette, to: url)
                case "ase":
                    try PaletteFileIO.saveASE(palette: paletteManager.currentPalette, to: url)
                default:
                    throw PaletteError.invalidFormat
                }
            } catch {
                importErrorMessage = error.localizedDescription
                showingImportError = true
            }
        }
    }
}

/// 개별 팔레트 행
struct PaletteRow: View {
    let palette: ColorPalette
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void

    @State private var isHovered = false
    @State private var isEditing = false
    @State private var editingName: String = ""

    var body: some View {
        HStack(spacing: 8) {
            // Preview colors
            HStack(spacing: 1) {
                ForEach(0..<min(8, palette.count), id: \.self) { index in
                    if let color = palette[UInt8(index)] {
                        Rectangle()
                            .fill(color)
                            .frame(width: 8, height: 20)
                    }
                }
            }
            .frame(width: 64, height: 20)
            .cornerRadius(2)

            // Name
            if isEditing {
                TextField("Palette Name", text: $editingName, onCommit: {
                    if !editingName.isEmpty {
                        onRename(editingName)
                    }
                    isEditing = false
                })
                .textFieldStyle(.plain)
                .font(.system(size: 11))
            } else {
                Text(palette.name)
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? Constants.Theme.accentBlue : Constants.Theme.textPrimary)
                    .onTapGesture(count: 2) {
                        editingName = palette.name
                        isEditing = true
                    }
            }

            Spacer()

            // Delete button (on hover)
            if isHovered {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Constants.Theme.accentBlue.opacity(0.15) : (isHovered ? Constants.Theme.hoverBackground : Color.clear))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

/// 새 팔레트 생성 다이얼로그
struct NewPaletteDialog: View {
    @Binding var paletteName: String
    @ObservedObject var paletteManager: PaletteManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("New Palette")
                .font(.headline)

            TextField("Palette Name", text: $paletteName)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)

                Button("Create") {
                    if !paletteName.isEmpty {
                        paletteManager.createPalette(name: paletteName)
                    }
                    dismiss()
                }
                .keyboardShortcut(.return)
                .disabled(paletteName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}

/// 프리셋 선택 다이얼로그
struct PresetPickerDialog: View {
    @ObservedObject var paletteManager: PaletteManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("Load Preset Palette")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(ColorPalette.presets) { preset in
                    Button(action: {
                        paletteManager.addPalette(preset)
                        paletteManager.switchPalette(to: preset.id)
                        dismiss()
                    }) {
                        HStack {
                            // Preview
                            HStack(spacing: 1) {
                                ForEach(0..<min(8, preset.count), id: \.self) { index in
                                    if let color = preset[UInt8(index)] {
                                        Rectangle()
                                            .fill(color)
                                            .frame(width: 12, height: 24)
                                    }
                                }
                            }
                            .frame(width: 96, height: 24)
                            .cornerRadius(2)

                            Text(preset.name)
                                .font(.system(size: 12))

                            Spacer()

                            Text("\(preset.count) colors")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Constants.Theme.sectionBackground)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding()
        .frame(width: 350, height: 300)
    }
}
