//
//  TextEditOverlayView.swift
//  Pixapper
//
//  Created by Claude on 2025-12-17.
//

import SwiftUI

/// 텍스트 입력 오버레이 - Selection Tool 스타일 (NSTextView 기반 IME 지원)
struct TextEditOverlayView: View {
    @Binding var textState: TextEditState
    @ObservedObject var viewModel: CanvasViewModel
    let pixelSize: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat

    var body: some View {
        ZStack {
            // 시각적 오버레이 (핸들과 테두리)
            Canvas { context, size in
                let rectX = offsetX + textState.rect.minX * pixelSize
                let rectY = offsetY + textState.rect.minY * pixelSize
                let rectWidth = textState.rect.width * pixelSize
                let rectHeight = textState.rect.height * pixelSize

                let borderRect = CGRect(
                    x: rectX,
                    y: rectY,
                    width: rectWidth,
                    height: rectHeight
                )

                // 테두리 (파란색 점선)
                var borderPath = Path()
                borderPath.addRect(borderRect)
                context.stroke(
                    borderPath,
                    with: .color(Color.accentColor),
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )

                // 핸들 렌더링
                drawResizeHandles(context: context, borderRect: borderRect)
            }
            .allowsHitTesting(false)  // 핸들 클릭은 CanvasView에서 처리

            // 투명 NSTextView - 키보드 입력용 (최상위)
            if textState.isEditing {
                let rectX = offsetX + textState.rect.minX * pixelSize
                let rectY = offsetY + textState.rect.minY * pixelSize
                let rectWidth = textState.rect.width * pixelSize  // 화면 포인트 크기
                let rectHeight = textState.rect.height * pixelSize  // 화면 포인트 크기

                TransparentTextEditor(
                    text: $textState.text,
                    cursorPosition: $textState.cursorPosition,
                    fontSize: CGFloat(viewModel.toolSettingsManager.textSettings.fontSize),
                    textBoxWidth: rectWidth,  // 화면 포인트 크기로 변경!
                    textBoxHeight: rectHeight,  // 화면 포인트 크기로 변경!
                    onTextChange: {
                        viewModel.updateTextPreview()
                    },
                    onCancel: {
                        viewModel.cancelText()
                    },
                    onCommit: {
                        viewModel.commitText()
                    }
                )
                .frame(width: rectWidth, height: rectHeight)
                .position(x: rectX + rectWidth / 2, y: rectY + rectHeight / 2)
            }
        }
    }

    private func drawResizeHandles(context: GraphicsContext, borderRect: CGRect) {
        let baseHandleSize: CGFloat = 11

        // 핸들 타입과 위치
        let handleTypes: [TextBoxHandle] = [
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .top, .bottom, .left, .right
        ]
        let handlePositions: [(x: CGFloat, y: CGFloat)] = [
            // 코너
            (borderRect.minX, borderRect.minY),      // topLeft
            (borderRect.maxX, borderRect.minY),      // topRight
            (borderRect.minX, borderRect.maxY),      // bottomLeft
            (borderRect.maxX, borderRect.maxY),      // bottomRight
            // 엣지
            (borderRect.midX, borderRect.minY),      // top
            (borderRect.midX, borderRect.maxY),      // bottom
            (borderRect.minX, borderRect.midY),      // left
            (borderRect.maxX, borderRect.midY)       // right
        ]

        for (index, position) in handlePositions.enumerated() {
            let handleType = handleTypes[index]
            let isHovered = viewModel.textBoxHoveredHandle == handleType
            let handleSize = isHovered ? baseHandleSize * 1.3 : baseHandleSize
            drawResizeHandle(context: context, position: position, size: handleSize, isHovered: isHovered)
        }
    }

    private func drawResizeHandle(context: GraphicsContext, position: (x: CGFloat, y: CGFloat), size: CGFloat, isHovered: Bool) {
        let handleRect = CGRect(
            x: position.x - size / 2,
            y: position.y - size / 2,
            width: size,
            height: size
        )

        // 그림자
        context.fill(Path(handleRect), with: .color(.black.opacity(0.15)))

        // 배경
        let fillColor = isHovered ? Color.accentColor.opacity(0.5) : .white
        context.fill(Path(handleRect), with: .color(fillColor))

        // 테두리
        let borderColor = Color.accentColor
        let borderWidth: CGFloat = isHovered ? 2.5 : 2
        context.stroke(Path(handleRect), with: .color(borderColor), lineWidth: borderWidth)
    }
}
