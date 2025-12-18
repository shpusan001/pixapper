//
//  TextTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-17.
//

import SwiftUI
import AppKit
import Combine

/// 텍스트 박스 리사이즈 핸들
enum TextBoxHandle {
    case topLeft, top, topRight
    case left, right
    case bottomLeft, bottom, bottomRight
    case inside  // 박스 내부 (이동용)
}

/// 텍스트 박스 모드
enum TextBoxMode {
    case idle
    case creating
    case moving(startPoint: CGPoint, originalRect: CGRect)
    case resizing(handle: TextBoxHandle, startPoint: CGPoint, originalRect: CGRect)
}

/// 텍스트 도구 - TextField 기반 IME 지원
@MainActor
class TextTool: BaseTool, CanvasTool {
    // MARK: - Constants
    private static let minBoxWidth = 3
    private static let minBoxHeight = 2

    // MARK: - Properties
    private var startPoint: (x: Int, y: Int)?
    private var mode: TextBoxMode = .idle
    private var hoveredHandle: TextBoxHandle?
    nonisolated(unsafe) private var settingsCancellable: AnyCancellable?
    nonisolated(unsafe) private var cursorTimer: Timer?

    nonisolated deinit {
        stopCursorTimer()
        stopSettingsObserver()
    }

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))

        // 기존 텍스트 박스가 있으면 핸들 또는 내부 클릭 체크
        if let textState = canvasViewModel?.textEditState {
            // 핸들 클릭 체크
            if let handle = detectHandle(at: point, rect: textState.rect) {
                if handle == .inside {
                    // 박스 내부 - 이동 모드
                    mode = .moving(startPoint: point, originalRect: textState.rect)
                } else {
                    // 핸들 - 리사이즈 모드
                    mode = .resizing(handle: handle, startPoint: point, originalRect: textState.rect)
                }
                return
            }

            // 박스 외부 클릭 - 커밋
            commitText()
        }

        // 새로운 텍스트 박스 생성 시작
        startPoint = (x, y)
        mode = .creating
    }

    func handleDrag(x: Int, y: Int) {
        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))

        switch mode {
        case .creating:
            guard let start = startPoint else { return }

            // 드래그 영역 계산
            let minX = min(start.x, x)
            let minY = min(start.y, y)
            let maxX = max(start.x, x)
            let maxY = max(start.y, y)
            let width = maxX - minX + 1
            let height = maxY - minY + 1

            // 프리뷰 업데이트
            canvasViewModel?.textEditState = TextEditState(
                rect: CGRect(x: minX, y: minY, width: width, height: height),
                isEditing: false
            )

        case .moving(let startPoint, let originalRect):
            // 이동 오프셋 계산
            let dx = point.x - startPoint.x
            let dy = point.y - startPoint.y

            // 새 위치 계산
            let newRect = CGRect(
                x: originalRect.minX + dx,
                y: originalRect.minY + dy,
                width: originalRect.width,
                height: originalRect.height
            )

            // 텍스트 상태 업데이트
            if var state = canvasViewModel?.textEditState {
                state.rect = newRect
                canvasViewModel?.textEditState = state
                renderText()
            }

        case .resizing(let handle, let startPoint, let originalRect):
            // 핸들에 따라 리사이즈
            let newRect = calculateResizedRect(
                handle: handle,
                currentPoint: point,
                startPoint: startPoint,
                originalRect: originalRect
            )

            // 최소 크기 체크
            if newRect.width >= CGFloat(Self.minBoxWidth) && newRect.height >= CGFloat(Self.minBoxHeight) {
                if var state = canvasViewModel?.textEditState {
                    state.rect = newRect
                    canvasViewModel?.textEditState = state
                    renderText()
                }
            }

        case .idle:
            break
        }
    }

    func handleUp(x: Int, y: Int) {
        switch mode {
        case .creating:
            guard let start = startPoint else { return }

            // 최소 크기 체크
            let minX = min(start.x, x)
            let minY = min(start.y, y)
            let maxX = max(start.x, x)
            let maxY = max(start.y, y)
            let width = maxX - minX + 1
            let height = maxY - minY + 1

            if width >= Self.minBoxWidth && height >= Self.minBoxHeight {
                // 텍스트 박스 생성 완료
                canvasViewModel?.textEditState = TextEditState(
                    rect: CGRect(x: minX, y: minY, width: width, height: height),
                    isEditing: true,
                    text: ""
                )

                // 설정 감지 시작
                startSettingsObserver()

                // 커서 타이머 시작
                startCursorTimer()
            }

            startPoint = nil

        case .moving, .resizing:
            // 이동/리사이즈 완료
            break

        case .idle:
            break
        }

        mode = .idle
    }

    // MARK: - Public Methods

    /// 텍스트 실시간 프리뷰 업데이트
    func updateTextPreview() {
        renderText()
    }

    /// 텍스트를 커밋하여 픽셀로 렌더링
    func commitText() {
        guard let state = canvasViewModel?.textEditState else { return }

        stopSettingsObserver()
        stopCursorTimer()

        // 텍스트가 있으면 커밋
        if !state.text.isEmpty {
            commitTextBuffer()
        }

        canvasViewModel?.textEditState = nil
    }

    private func commitTextBuffer() {
        guard let state = canvasViewModel?.textEditState,
              let timelineVM = timelineViewModel,
              currentLayerIndex < layerViewModel.layers.count else { return }

        let layerId = layerViewModel.layers[currentLayerIndex].id
        var oldPixels: [PixelChange] = []
        var newPixels: [PixelChange] = []

        // 프리뷰 픽셀을 실제로 적용
        for pixel in state.previewPixels {
            var oldColor: Color? = nil
            if let framePixels = timelineVM.getCurrentFramePixels(layerId: layerId),
               pixel.y >= 0, pixel.y < framePixels.count,
               pixel.x >= 0, pixel.x < framePixels[pixel.y].count {
                oldColor = framePixels[pixel.y][pixel.x]
            }

            oldPixels.append(PixelChange(x: pixel.x, y: pixel.y, color: oldColor))
            newPixels.append(PixelChange(x: pixel.x, y: pixel.y, color: pixel.color))

            timelineVM.setPixel(layerId: layerId, x: pixel.x, y: pixel.y, color: pixel.color)
        }

        // Command 생성
        if !newPixels.isEmpty {
            let command = DrawCommand(
                timelineViewModel: timelineVM,
                layerId: layerId,
                oldPixels: oldPixels,
                newPixels: newPixels
            )
            commandManager.addExecutedCommand(command)
        }

        timelineVM.pixelStateManager?.syncToTimeline()
    }

    /// 텍스트 편집 취소
    func cancelText() {
        stopSettingsObserver()
        stopCursorTimer()
        canvasViewModel?.textEditState = nil
    }

    // MARK: - Cursor Timer

    private func startCursorTimer() {
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.canvasViewModel?.textEditState?.cursorVisible.toggle()
            }
        }
    }

    nonisolated private func stopCursorTimer() {
        cursorTimer?.invalidate()
        cursorTimer = nil
    }

    // MARK: - Settings Observer

    private func startSettingsObserver() {
        settingsCancellable = toolSettingsManager.$textSettings
            .dropFirst()  // 초기값 무시
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.renderText()
                }
            }
    }

    nonisolated private func stopSettingsObserver() {
        settingsCancellable?.cancel()
        settingsCancellable = nil
    }

    // MARK: - Text Rendering

    private func renderText() {
        guard let state = canvasViewModel?.textEditState else { return }

        let settings = toolSettingsManager.textSettings
        let color = toolSettingsManager.colorManager.primaryColor
        let font = getFont(settings: settings)

        var previewPixels: [(x: Int, y: Int, color: Color)] = []

        // 텍스트가 비어있으면 프리뷰도 비움
        if state.text.isEmpty {
            canvasViewModel?.textEditState?.previewPixels = []
            return
        }

        // NSLayoutManager를 사용하여 실제 줄바꿈을 계산
        let textStorage = NSTextStorage(string: state.text)
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: state.rect.width, height: CGFloat.greatestFiniteMagnitude))

        textContainer.lineFragmentPadding = 0  // 여백 제거 (TransparentTextEditor와 동일)
        layoutManager.addTextContainer(textContainer)
        textStorage.addLayoutManager(layoutManager)

        // 폰트 속성 적용
        textStorage.addAttributes([.font: font], range: NSRange(location: 0, length: textStorage.length))

        // 레이아웃 강제 계산
        layoutManager.glyphRange(for: textContainer)

        // 각 줄 조각(line fragment)을 순회하여 렌더링
        layoutManager.enumerateLineFragments(forGlyphRange: NSRange(location: 0, length: layoutManager.numberOfGlyphs)) { (rect, usedRect, textContainer, glyphRange, stop) in
            // 현재 줄의 텍스트 추출
            let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let lineText = (textStorage.string as NSString).substring(with: characterRange)

            // 빈 줄은 건너뛰기 (높이는 자동으로 계산됨)
            if lineText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return
            }

            // 줄 렌더링
            if let pixels = self.renderTextLine(lineText, font: font, color: color) {
                let offsetY = Int(usedRect.minY)

                for (dy, row) in pixels.enumerated() {
                    for (dx, shouldDraw) in row.enumerated() {
                        if shouldDraw {
                            let px = Int(state.rect.minX) + dx
                            let py = Int(state.rect.minY) + offsetY + dy
                            previewPixels.append((x: px, y: py, color: color))
                        }
                    }
                }
            }
        }

        canvasViewModel?.textEditState?.previewPixels = previewPixels
    }

    private func renderTextLine(_ text: String, font: NSFont, color: Color) -> [[Bool]]? {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor(color)
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let width = Int(ceil(textSize.width))
        let height = Int(ceil(textSize.height))

        guard width > 0 && height > 0 else { return nil }

        // 고품질 렌더링을 위한 CGContext 사용
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }

        // 고품질 텍스트 렌더링 설정
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.setAllowsAntialiasing(true)
        context.setAllowsFontSmoothing(true)
        context.setAllowsFontSubpixelPositioning(true)
        context.setAllowsFontSubpixelQuantization(false)

        // 배경 투명하게
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))

        // NSGraphicsContext로 변환하여 텍스트 그리기
        let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
        NSGraphicsContext.current = nsContext

        attributedString.draw(at: .zero)

        NSGraphicsContext.current = nil

        // CGImage로 변환
        guard let cgImage = context.makeImage() else { return nil }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))

        return imageToPixels(image: image, color: color)
    }

    private func getFont(settings: TextToolSettings) -> NSFont {
        var traits: NSFontTraitMask = []
        if settings.isBold {
            traits.insert(.boldFontMask)
        }
        if settings.isItalic {
            traits.insert(.italicFontMask)
        }

        if traits.isEmpty {
            return NSFont(name: settings.fontName, size: settings.fontSize) ?? NSFont.systemFont(ofSize: settings.fontSize)
        } else {
            let baseFont = NSFont(name: settings.fontName, size: settings.fontSize) ?? NSFont.systemFont(ofSize: settings.fontSize)
            return NSFontManager.shared.convert(baseFont, toHaveTrait: traits)
        }
    }

    // MARK: - Image to Pixels Conversion

    private func imageToPixels(image: NSImage, color: Color) -> [[Bool]]? {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return nil
        }

        let width = bitmap.pixelsWide
        let height = bitmap.pixelsHigh

        var pixels: [[Bool]] = Array(repeating: Array(repeating: false, count: width), count: height)

        // 각 픽셀의 알파값 확인
        for y in 0..<height {
            for x in 0..<width {
                if let pixelColor = bitmap.colorAt(x: x, y: y) {
                    // 알파가 0보다 크면 픽셀로 간주
                    if pixelColor.alphaComponent > 0.1 {
                        pixels[y][x] = true
                    }
                }
            }
        }

        return pixels
    }

    // MARK: - Handle Detection & Resize

    /// 핸들 감지 (픽셀 좌표에서 핸들 클릭 여부 체크)
    private func detectHandle(at point: CGPoint, rect: CGRect) -> TextBoxHandle? {
        let handleTolerance: CGFloat = 3  // 핸들 감지 범위 (픽셀)

        // 코너 핸들
        if abs(point.x - rect.minX) <= handleTolerance && abs(point.y - rect.minY) <= handleTolerance {
            return .topLeft
        }
        if abs(point.x - rect.maxX) <= handleTolerance && abs(point.y - rect.minY) <= handleTolerance {
            return .topRight
        }
        if abs(point.x - rect.minX) <= handleTolerance && abs(point.y - rect.maxY) <= handleTolerance {
            return .bottomLeft
        }
        if abs(point.x - rect.maxX) <= handleTolerance && abs(point.y - rect.maxY) <= handleTolerance {
            return .bottomRight
        }

        // 엣지 핸들
        if abs(point.y - rect.minY) <= handleTolerance && point.x > rect.minX + handleTolerance && point.x < rect.maxX - handleTolerance {
            return .top
        }
        if abs(point.y - rect.maxY) <= handleTolerance && point.x > rect.minX + handleTolerance && point.x < rect.maxX - handleTolerance {
            return .bottom
        }
        if abs(point.x - rect.minX) <= handleTolerance && point.y > rect.minY + handleTolerance && point.y < rect.maxY - handleTolerance {
            return .left
        }
        if abs(point.x - rect.maxX) <= handleTolerance && point.y > rect.minY + handleTolerance && point.y < rect.maxY - handleTolerance {
            return .right
        }

        // 박스 내부
        if rect.contains(point) {
            return .inside
        }

        return nil
    }

    /// 리사이즈된 사각형 계산
    private func calculateResizedRect(
        handle: TextBoxHandle,
        currentPoint: CGPoint,
        startPoint: CGPoint,
        originalRect: CGRect
    ) -> CGRect {
        let dx = currentPoint.x - startPoint.x
        let dy = currentPoint.y - startPoint.y

        var newRect = originalRect

        switch handle {
        case .topLeft:
            newRect.origin.x = originalRect.minX + dx
            newRect.origin.y = originalRect.minY + dy
            newRect.size.width = originalRect.width - dx
            newRect.size.height = originalRect.height - dy

        case .top:
            newRect.origin.y = originalRect.minY + dy
            newRect.size.height = originalRect.height - dy

        case .topRight:
            newRect.origin.y = originalRect.minY + dy
            newRect.size.width = originalRect.width + dx
            newRect.size.height = originalRect.height - dy

        case .left:
            newRect.origin.x = originalRect.minX + dx
            newRect.size.width = originalRect.width - dx

        case .right:
            newRect.size.width = originalRect.width + dx

        case .bottomLeft:
            newRect.origin.x = originalRect.minX + dx
            newRect.size.width = originalRect.width - dx
            newRect.size.height = originalRect.height + dy

        case .bottom:
            newRect.size.height = originalRect.height + dy

        case .bottomRight:
            newRect.size.width = originalRect.width + dx
            newRect.size.height = originalRect.height + dy

        case .inside:
            break
        }

        // 음수 크기 방지 (반전 허용)
        if newRect.width < 0 {
            newRect.origin.x += newRect.width
            newRect.size.width = -newRect.width
        }
        if newRect.height < 0 {
            newRect.origin.y += newRect.height
            newRect.size.height = -newRect.height
        }

        return newRect
    }

    // MARK: - Hover & Outside Click

    func updateHover(x: Int, y: Int) {
        guard let textState = canvasViewModel?.textEditState else {
            canvasViewModel?.textBoxHoveredHandle = nil
            return
        }

        let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
        let handle = detectHandle(at: point, rect: textState.rect)
        canvasViewModel?.textBoxHoveredHandle = handle
    }

    func clearHover() {
        canvasViewModel?.textBoxHoveredHandle = nil
    }

    func handleOutsideClick() {
        // 텍스트 박스 외부 클릭 시 커밋
        if canvasViewModel?.textEditState != nil {
            commitText()
        }
    }
}
