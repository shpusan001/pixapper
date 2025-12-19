//
//  ExportPreviewView.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/18/25.
//

import SwiftUI

struct ExportPreviewView: View {
    @ObservedObject var viewModel: ExportViewModel

    var body: some View {
        VStack(spacing: 12) {
            Text("Preview")
                .font(.headline)
                .foregroundColor(Constants.Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                // Checkerboard background
                CheckerboardPattern()
                    .opacity(0.5)

                if viewModel.isGeneratingPreview {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: Constants.Theme.accentBlue))
                } else if let previewImage = viewModel.previewImage {
                    Image(nsImage: previewImage)
                        .resizable()
                        .interpolation(.none) // Pixel-perfect
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // No preview for GIF/MP4
                    VStack(spacing: 12) {
                        Image(systemName: isAnimatedFormat ? "film" : "photo")
                            .font(.system(size: 40))
                            .foregroundColor(Constants.Theme.textDisabled)
                        Text(isAnimatedFormat ? "Preview not available\nfor animations" : "No Preview")
                            .font(.callout)
                            .foregroundColor(Constants.Theme.textDisabled)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Constants.Theme.backgroundDark)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Constants.Theme.divider, lineWidth: 1)
            )

            // Dimensions info
            if let previewImage = viewModel.previewImage {
                HStack {
                    Image(systemName: "ruler")
                        .foregroundColor(Constants.Theme.textSecondary)
                        .font(.caption)
                    Text("\(Int(previewImage.size.width)) × \(Int(previewImage.size.height)) px")
                        .font(.caption)
                        .foregroundColor(Constants.Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var isAnimatedFormat: Bool {
        viewModel.selectedFormat == .gif || viewModel.selectedFormat == .mp4
    }
}

// MARK: - Checkerboard Pattern

struct CheckerboardPattern: View {
    let squareSize: CGFloat = 8

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let columns = Int(ceil(size.width / squareSize))
                let rows = Int(ceil(size.height / squareSize))

                for row in 0..<rows {
                    for col in 0..<columns {
                        let isEven = (row + col) % 2 == 0
                        let color = isEven ?
                            Color(white: Constants.Canvas.checkerboardLightGray) :
                            Color(white: Constants.Canvas.checkerboardDarkGray)

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
