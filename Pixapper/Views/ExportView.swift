//
//  ExportView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var timelineViewModel: TimelineViewModel
    let canvasWidth: Int
    let canvasHeight: Int

    @State private var exportType: ExportType = .singleImage
    @State private var spriteSheetLayout: SpriteSheetLayout = .horizontal
    @State private var spriteSheetPadding: Int = 0
    @State private var sequenceBaseName: String = "frame"
    @State private var showingErrorAlert = false
    @State private var errorMessage: String = ""

    enum ExportType: String, CaseIterable, Identifiable {
        case singleImage = "Single Image"
        case spriteSheet = "Sprite Sheet"
        case pngSequence = "PNG Sequence"

        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Export")
                .font(.title)

            Divider()

            // Export type selector
            Picker("Export Type", selection: $exportType) {
                ForEach(ExportType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)

            // Export options based on type
            Group {
                switch exportType {
                case .singleImage:
                    singleImageOptions
                case .spriteSheet:
                    spriteSheetOptions
                case .pngSequence:
                    pngSequenceOptions
                }
            }
            .padding(.vertical, 8)

            Divider()

            // Export button
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Export") {
                    performExport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: Constants.Layout.Panel.exportViewWidth)
        .alert("Export 실패", isPresented: $showingErrorAlert) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private var singleImageOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Export current frame as PNG")
                .font(.callout)
                .foregroundColor(.secondary)

            Text("Frame: \(timelineViewModel.currentFrameIndex + 1)/\(timelineViewModel.totalFrames)")
                .font(.callout)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spriteSheetOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Combine all frames into a single sprite sheet")
                .font(.callout)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Layout")
                    .font(.callout)
                Picker("Layout", selection: $spriteSheetLayout) {
                    ForEach(SpriteSheetLayout.allCases) { layout in
                        Text(layout.rawValue).tag(layout)
                    }
                }
                .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Padding")
                        .font(.callout)
                    Spacer()
                    Text("\(spriteSheetPadding)px")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                Slider(value: Binding(
                    get: { Double(spriteSheetPadding) },
                    set: { spriteSheetPadding = Int($0) }
                ), in: 0...16, step: 1)
            }

            Text("\(timelineViewModel.totalFrames) frames")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pngSequenceOptions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export each frame as a separate PNG file")
                .font(.callout)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Base Name")
                    .font(.callout)
                TextField("Base name", text: $sequenceBaseName)
                    .textFieldStyle(.roundedBorder)

                Text("Files will be named: \(sequenceBaseName)_001.png, \(sequenceBaseName)_002.png, ...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("\(timelineViewModel.totalFrames) frames will be exported")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func performExport() {
        switch exportType {
        case .singleImage:
            exportSingleImage(width: canvasWidth, height: canvasHeight)
        case .spriteSheet:
            exportSpriteSheet(width: canvasWidth, height: canvasHeight)
        case .pngSequence:
            exportPNGSequence(width: canvasWidth, height: canvasHeight)
        }

        dismiss()
    }

    private func exportSingleImage(width: Int, height: Int) {
        let resolvedFrames = timelineViewModel.getResolvedFrames()
        let currentFrame = resolvedFrames[timelineViewModel.currentFrameIndex]
        let layers = timelineViewModel.layerViewModel.layers

        if let image = ExportManager.exportSingleImage(frame: currentFrame, layers: layers, width: width, height: height) {
            ExportManager.savePNG(image: image)
        }
    }

    private func exportSpriteSheet(width: Int, height: Int) {
        let resolvedFrames = timelineViewModel.getResolvedFrames()
        let layers = timelineViewModel.layerViewModel.layers

        if let image = ExportManager.exportSpriteSheet(
            frames: resolvedFrames,
            layers: layers,
            width: width,
            height: height,
            layout: spriteSheetLayout,
            padding: spriteSheetPadding
        ) {
            ExportManager.savePNG(image: image)
        }
    }

    private func exportPNGSequence(width: Int, height: Int) {
        let resolvedFrames = timelineViewModel.getResolvedFrames()
        let layers = timelineViewModel.layerViewModel.layers

        ExportManager.chooseDirectory { url in
            guard let directoryURL = url else { return }

            let result = ExportManager.exportPNGSequence(
                frames: resolvedFrames,
                layers: layers,
                width: width,
                height: height,
                directoryURL: directoryURL,
                baseName: sequenceBaseName
            )

            switch result {
            case .success:
                // 성공 - 아무것도 하지 않음 (필요시 성공 알림 추가 가능)
                break
            case .failure(let error):
                errorMessage = error.localizedDescription
                showingErrorAlert = true
            }
        }
    }
}
