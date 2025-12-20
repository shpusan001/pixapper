//
//  FillTool.swift
//  Pixapper
//
//  Created by Claude on 2025-12-13.
//

import SwiftUI

/// 채우기 도구 상태
enum FillToolState {
    case idle
    case settingLinearGradient(startX: Int, startY: Int)
    case settingRadialGradient(centerX: Int, centerY: Int)
}

/// 채우기 도구
@MainActor
class FillTool: BaseTool, CanvasTool {

    private var toolState: FillToolState = .idle

    func handleDown(x: Int, y: Int, altPressed: Bool) {
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🖱️ FillTool.handleDown at (\(x), \(y))")
        let settings = toolSettingsManager.fillSettings
        print("   fillType: \(settings.fillType)")

        // 그래디언트 타입이면 드래그 모드 시작
        if settings.fillType == .linear {
            print("   → Starting linear gradient drag")
            toolState = .settingLinearGradient(startX: x, startY: y)
            updateGradientPreview(currentX: x, currentY: y)
            return
        } else if settings.fillType == .radial {
            print("   → Starting radial gradient drag")
            toolState = .settingRadialGradient(centerX: x, centerY: y)
            updateGradientPreview(currentX: x, currentY: y)
            return
        }

        // Solid 타입: 즉시 Fill 실행
        print("   → Solid fill mode")
        performFill(at: x, y: y)
    }

    func handleDrag(x: Int, y: Int) {
        // 그래디언트 설정 중이면 프리뷰 업데이트
        switch toolState {
        case .settingLinearGradient, .settingRadialGradient:
            updateGradientPreview(currentX: x, currentY: y)
        case .idle:
            break
        }
    }

    func handleUp(x: Int, y: Int) {
        // 그래디언트 설정 완료 후 Fill 실행
        switch toolState {
        case .settingLinearGradient(let startX, let startY):
            finalizeLinearGradient(startX: startX, startY: startY, endX: x, endY: y)
            performFill(at: startX, y: startY)
            toolState = .idle
            clearGradientPreview()

        case .settingRadialGradient(let centerX, let centerY):
            finalizeRadialGradient(centerX: centerX, centerY: centerY, edgeX: x, edgeY: y)
            performFill(at: centerX, y: centerY)
            toolState = .idle
            clearGradientPreview()

        case .idle:
            break
        }
    }

    // MARK: - Private Methods

    /// PixelValue를 Color로 변환 (특정 좌표에서)
    private func pixelValueToColor(_ pixelValue: PixelValue, at x: Int? = nil, y: Int? = nil) -> Color {
        switch pixelValue {
        case .transparent:
            return .clear
        case .indexed(let colorIndex):
            return timelineViewModel?.pixelStateManager.currentPalette.getColor(at: colorIndex) ?? .clear
        case .gradient:
            // 그래디언트는 좌표가 주어지면 해당 위치의 색상 계산
            if let x = x, let y = y,
               let pixelStateManager = timelineViewModel?.pixelStateManager {
                let renderContext = DefaultRenderContext(
                    palette: pixelStateManager.currentPalette,
                    gradients: pixelStateManager.gradientLibrary
                )
                let point = PixelPoint(x, y)
                return renderContext.resolve(pixelValue, at: point) ?? .clear
            }
            // 좌표 없이 비교하는 경우, 그래디언트는 고유 ID로만 구분
            // (같은 그래디언트면 같은 색으로 간주)
            return Color(red: 0.5, green: 0.5, blue: 0.5)  // 중간 회색으로 표시
        case .directColor(let rgba8):
            return Color(
                red: Double(rgba8.r) / 255.0,
                green: Double(rgba8.g) / 255.0,
                blue: Double(rgba8.b) / 255.0,
                opacity: Double(rgba8.a) / 255.0
            )
        }
    }

    /// 단색 PixelValue 생성
    private func createSolidFillValue(fillColor: Color) -> PixelValue {
        guard let paletteManager = timelineViewModel?.pixelStateManager.paletteManager else {
            return .transparent
        }

        if let colorIndex = paletteManager.findClosestColorIndex(fillColor) {
            return .indexed(colorIndex)
        }

        // 색상을 찾지 못하면 팔레트에 추가 시도
        if let newIndex = paletteManager.addColor(fillColor) {
            return .indexed(newIndex)
        }

        // 팔레트가 가득 찼으면 가장 가까운 색상 강제 사용 (0번 인덱스)
        return .indexed(0)
    }

    /// 두 색상 보간 (0.0 = color1, 1.0 = color2)
    private func lerpColor(_ color1: Color, _ color2: Color, t: Double) -> Color {
        let t = min(max(t, 0.0), 1.0)

        guard let rgb1 = color1.rgbComponents(),
              let rgb2 = color2.rgbComponents() else {
            return color1
        }

        let r = rgb1.r + (rgb2.r - rgb1.r) * t
        let g = rgb1.g + (rgb2.g - rgb1.g) * t
        let b = rgb1.b + (rgb2.b - rgb1.b) * t

        return Color(red: r, green: g, blue: b)
    }

    /// 좌표에 따른 그래디언트 색상을 PixelValue로 변환 (RGB 보간, 팔레트 추가)
    private func createGradientFillValue(at x: Int, y: Int) -> PixelValue {
        let settings = toolSettingsManager.fillSettings
        let primaryColor = toolSettingsManager.colorManager.primaryColor
        let secondaryColor = toolSettingsManager.colorManager.secondaryColor

        guard let paletteManager = timelineViewModel?.pixelStateManager.paletteManager else {
            return .transparent
        }

        // position 계산 (0.0 = primary, 1.0 = secondary)
        let position: Double

        switch settings.fillType {
        case .linear:
            position = calculateLinearPosition(x: x, y: y)
        case .radial:
            position = calculateRadialPosition(x: x, y: y)
        default:
            position = 0.0
        }

        // RGB 보간으로 정확한 중간색 계산
        let interpolatedColor = lerpColor(primaryColor, secondaryColor, t: position)

        // RGB 값을 직접 PixelValue로 저장 (팔레트 불필요!)
        if let rgb = interpolatedColor.rgbComponents() {
            let rgba8 = RGBA8(
                r: UInt8(max(0, min(255, Int(rgb.r * 255.0)))),
                g: UInt8(max(0, min(255, Int(rgb.g * 255.0)))),
                b: UInt8(max(0, min(255, Int(rgb.b * 255.0)))),
                a: UInt8(max(0, min(255, Int(rgb.a * 255.0))))
            )
            return .directColor(rgba8)
        }

        return .transparent
    }

    /// Linear 그래디언트 position 계산 (드래그 시작점→끝점 기준)
    private func calculateLinearPosition(x: Int, y: Int) -> Double {
        let settings = toolSettingsManager.fillSettings

        let startX = Double(settings.linearStartX)
        let startY = Double(settings.linearStartY)
        let endX = Double(settings.linearEndX)
        let endY = Double(settings.linearEndY)

        // 그래디언트 벡터 (시작→끝)
        let vx = endX - startX
        let vy = endY - startY
        let vLength = sqrt(vx * vx + vy * vy)

        // 벡터 길이가 0이면 (드래그 안했으면) 중간값
        if vLength < 1.0 {
            return 0.5
        }

        // 현재 픽셀 벡터 (시작→픽셀)
        let px = Double(x) - startX
        let py = Double(y) - startY

        // 투영: dot(p, v) / dot(v, v)
        let projection = (px * vx + py * vy) / (vLength * vLength)

        // 0.0 (시작점) ~ 1.0 (끝점)
        return max(0.0, min(projection, 1.0))
    }

    /// Radial 그래디언트 position 계산 (드래그 중심→반경끝 기준)
    private func calculateRadialPosition(x: Int, y: Int) -> Double {
        let settings = toolSettingsManager.fillSettings

        let centerX = Double(settings.radialCenterX)
        let centerY = Double(settings.radialCenterY)
        let radius = settings.radialRadius

        // 반경이 0이면 (드래그 안했으면) 중간값
        if radius < 1.0 {
            return 0.5
        }

        // 중심으로부터의 거리
        let dx = Double(x) - centerX
        let dy = Double(y) - centerY
        let distance = sqrt(dx * dx + dy * dy)

        // 0.0 (중심) ~ 1.0 (반경 끝)
        return min(distance / radius, 1.0)
    }

    /// Flood Fill - Solid (단색)
    private func floodFill(x: Int, y: Int, solidFillValue fillValue: PixelValue, tolerance: Double) {
        print("🎨 floodFill START at (\(x), \(y))")
        guard let canvas = canvasViewModel,
              let timelineVM = timelineViewModel,
              currentLayerIndex < layerViewModel.layers.count else {
            print("❌ Guard failed")
            return
        }

        let layerId = layerViewModel.layers[currentLayerIndex].id
        guard var pixels = timelineVM.getCurrentFramePixels(layerId: layerId) else {
            print("❌ No pixels")
            return
        }
        print("✓ Canvas size: \(canvas.canvas.width) x \(canvas.canvas.height)")
        print("✓ Pixels array: \(pixels.count) rows")

        // 시작점의 픽셀 값 가져오기
        guard y >= 0, y < pixels.count, x >= 0, x < pixels[y].count else {
            print("❌ Out of bounds: x=\(x), y=\(y)")
            return
        }
        let targetValue = pixels[y][x]
        print("✓ targetValue: \(targetValue)")
        print("✓ fillValue: \(fillValue)")

        // PixelValue가 같으면 스킵 (tolerance=0일 때 간단한 체크)
        if tolerance == 0 && targetValue == fillValue {
            print("⚠️ Same pixel value, skipping")
            return
        }

        // 색상 비교는 tolerance > 0일 때만
        let targetColor = pixelValueToColor(targetValue, at: x, y: y)
        let fillColor = pixelValueToColor(fillValue, at: x, y: y)
        print("✓ targetColor: \(targetColor)")
        print("✓ fillColor: \(fillColor)")

        if Color.areEqual(targetColor, fillColor, tolerance: tolerance) {
            print("⚠️ Same color, skipping")
            return
        }
        print("✓ Colors different, starting fill...")

        var changedPixels: [PixelChange] = []
        var oldPixels: [PixelChange] = []
        var stack = [(x: Int, y: Int)]()
        var visited = Set<String>()  // "x,y" 형식으로 저장

        stack.append((x, y))
        visited.insert("\(x),\(y)")
        print("✓ Stack initialized with (\(x), \(y))")

        var loopCount = 0
        while !stack.isEmpty {
            let point = stack.removeLast()
            let px = point.x
            let py = point.y
            loopCount += 1

            if loopCount <= 5 {
                print("  Loop \(loopCount): Processing (\(px), \(py))")
            }

            guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else {
                if loopCount <= 5 { print("    ↳ Out of canvas bounds") }
                continue
            }
            guard py < pixels.count, px < pixels[py].count else {
                if loopCount <= 5 { print("    ↳ Out of pixel array bounds") }
                continue
            }

            let currentValue = pixels[py][px]

            // PixelValue 직접 비교 (tolerance=0일 때)
            let isMatch: Bool
            if tolerance == 0 {
                isMatch = (currentValue == targetValue)
                if loopCount <= 5 {
                    print("    ↳ PixelValue check: \(currentValue) == \(targetValue) ? \(isMatch)")
                }
            } else {
                // tolerance > 0일 때만 Color 비교
                let currentColor = pixelValueToColor(currentValue, at: px, y: py)
                isMatch = Color.areEqual(currentColor, targetColor, tolerance: tolerance)
                if loopCount <= 5 {
                    print("    ↳ Color check: \(currentColor) ~= \(targetColor) ? \(isMatch)")
                }
            }

            if !isMatch {
                if loopCount <= 5 { print("    ↳ No match, skipping") }
                continue
            }

            if loopCount <= 5 { print("    ↳ Match! Filling...") }

            // 이전 상태 저장
            oldPixels.append(PixelChange(x: px, y: py, value: currentValue))
            changedPixels.append(PixelChange(x: px, y: py, value: fillValue))

            // 로컬 pixels 배열 업데이트 (다음 비교를 위해)
            pixels[py][px] = fillValue

            // 인접 픽셀 추가 (방문 안한 곳만)
            let neighbors = [(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)]
            for (nx, ny) in neighbors {
                let key = "\(nx),\(ny)"
                if !visited.contains(key) {
                    visited.insert(key)
                    stack.append((nx, ny))
                }
            }
        }

        print("✓ Loop completed: \(loopCount) iterations, \(changedPixels.count) pixels changed")

        // 모든 변경사항을 한번에 적용
        if !changedPixels.isEmpty {
            print("✓ Applying changes...")
            for change in changedPixels {
                timelineVM.setPixel(layerId: layerId, x: change.x, y: change.y, value: change.value)
            }

            let command = DrawCommand(
                timelineViewModel: timelineViewModel,
                layerId: layerId,
                frameIndex: timelineVM.currentFrameIndex,
                oldPixels: oldPixels,
                newPixels: changedPixels
            )
            commandManager.addExecutedCommand(command)
            print("✅ Fill COMPLETE!")
        } else {
            print("⚠️ No pixels changed!")
        }
    }

    /// Flood Fill - Gradient (픽셀마다 색상 계산)
    private func floodFillGradient(x: Int, y: Int, tolerance: Double) {
        print("🎨 floodFillGradient START at (\(x), \(y))")
        guard let canvas = canvasViewModel,
              let timelineVM = timelineViewModel,
              currentLayerIndex < layerViewModel.layers.count else {
            print("❌ Guard failed")
            return
        }

        let layerId = layerViewModel.layers[currentLayerIndex].id
        guard var pixels = timelineVM.getCurrentFramePixels(layerId: layerId) else {
            print("❌ No pixels")
            return
        }

        // 시작점의 픽셀 값 가져오기
        guard y >= 0, y < pixels.count, x >= 0, x < pixels[y].count else {
            print("❌ Out of bounds")
            return
        }
        let targetValue = pixels[y][x]
        print("✓ targetValue: \(targetValue)")

        var changedPixels: [PixelChange] = []
        var oldPixels: [PixelChange] = []
        var stack = [(x: Int, y: Int)]()
        var visited = Set<String>()

        stack.append((x, y))
        visited.insert("\(x),\(y)")

        var loopCount = 0
        while !stack.isEmpty {
            let point = stack.removeLast()
            let px = point.x
            let py = point.y
            loopCount += 1

            guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else {
                continue
            }
            guard py < pixels.count, px < pixels[py].count else {
                continue
            }

            let currentValue = pixels[py][px]

            // 타겟 픽셀과 같은 타입인지만 체크
            let isMatch = (currentValue == targetValue)
            if !isMatch {
                continue
            }

            // 이 픽셀의 그래디언트 색상 계산
            let fillValue = createGradientFillValue(at: px, y: py)

            // 이전 상태 저장
            oldPixels.append(PixelChange(x: px, y: py, value: currentValue))
            changedPixels.append(PixelChange(x: px, y: py, value: fillValue))

            // 로컬 pixels 배열 업데이트
            pixels[py][px] = fillValue

            // 인접 픽셀 추가
            let neighbors = [(px + 1, py), (px - 1, py), (px, py + 1), (px, py - 1)]
            for (nx, ny) in neighbors {
                let key = "\(nx),\(ny)"
                if !visited.contains(key) {
                    visited.insert(key)
                    stack.append((nx, ny))
                }
            }
        }

        print("✓ Gradient fill completed: \(changedPixels.count) pixels")

        // 모든 변경사항을 한번에 적용
        if !changedPixels.isEmpty {
            for change in changedPixels {
                timelineVM.setPixel(layerId: layerId, x: change.x, y: change.y, value: change.value)
            }

            let command = DrawCommand(
                timelineViewModel: timelineViewModel,
                layerId: layerId,
                frameIndex: timelineVM.currentFrameIndex,
                oldPixels: oldPixels,
                newPixels: changedPixels
            )
            commandManager.addExecutedCommand(command)
            print("✅ Gradient fill COMPLETE!")
        }
    }

    // MARK: - Gradient Drag Interface

    /// Fill 수행 (공통)
    private func performFill(at x: Int, y: Int) {
        let settings = toolSettingsManager.fillSettings

        if settings.fillType == .solid {
            // Solid: 단일 색상으로 채우기
            let fillColor = toolSettingsManager.colorManager.primaryColor
            let fillValue = createSolidFillValue(fillColor: fillColor)
            floodFill(x: x, y: y, solidFillValue: fillValue, tolerance: settings.tolerance)
        } else {
            // Gradient: 픽셀마다 다른 색상으로 채우기
            floodFillGradient(x: x, y: y, tolerance: settings.tolerance)
        }
    }

    /// Linear Gradient 드래그 좌표 저장
    private func finalizeLinearGradient(startX: Int, startY: Int, endX: Int, endY: Int) {
        // 드래그 좌표 저장
        toolSettingsManager.fillSettings.linearStartX = startX
        toolSettingsManager.fillSettings.linearStartY = startY
        toolSettingsManager.fillSettings.linearEndX = endX
        toolSettingsManager.fillSettings.linearEndY = endY
    }

    /// Radial Gradient 드래그 좌표 저장
    private func finalizeRadialGradient(centerX: Int, centerY: Int, edgeX: Int, edgeY: Int) {
        let dx = Double(edgeX - centerX)
        let dy = Double(edgeY - centerY)
        let radius = sqrt(dx * dx + dy * dy)

        // 좌표와 반경 저장
        toolSettingsManager.fillSettings.radialCenterX = centerX
        toolSettingsManager.fillSettings.radialCenterY = centerY
        toolSettingsManager.fillSettings.radialRadius = radius
    }

    /// 그래디언트 프리뷰 업데이트
    private func updateGradientPreview(currentX: Int, currentY: Int) {
        guard let canvas = canvasViewModel else { return }

        switch toolState {
        case .settingLinearGradient(let startX, let startY):
            // Linear: 시작점 → 현재점 선
            canvas.gradientPreview = .linear(
                start: CGPoint(x: startX, y: startY),
                end: CGPoint(x: currentX, y: currentY)
            )

        case .settingRadialGradient(let centerX, let centerY):
            // Radial: 중심점과 반경
            let dx = Double(currentX - centerX)
            let dy = Double(currentY - centerY)
            let radius = sqrt(dx * dx + dy * dy)

            canvas.gradientPreview = .radial(
                center: CGPoint(x: centerX, y: centerY),
                radius: radius
            )

        case .idle:
            break
        }
    }

    /// 그래디언트 프리뷰 제거
    private func clearGradientPreview() {
        canvasViewModel?.gradientPreview = nil
    }
}
