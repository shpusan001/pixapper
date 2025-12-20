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
        guard let pixelStateManager = timelineViewModel?.pixelStateManager else {
            return .clear
        }

        // RenderContext로 통일된 렌더링
        let renderContext = DefaultRenderContext(
            palette: pixelStateManager.currentPalette,
            gradients: pixelStateManager.gradientLibrary
        )

        if let x = x, let y = y {
            let point = PixelPoint(x, y)
            return renderContext.resolve(pixelValue, at: point) ?? .clear
        } else {
            return renderContext.resolve(pixelValue) ?? .clear
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

    /// 좌표에 따른 그래디언트 색상을 PixelValue로 변환 (paletteGradient 방식)
    private func createGradientFillValue(at x: Int, y: Int) -> PixelValue {
        let settings = toolSettingsManager.fillSettings
        let primaryColor = toolSettingsManager.colorManager.primaryColor
        let secondaryColor = toolSettingsManager.colorManager.secondaryColor

        guard let paletteManager = timelineViewModel?.pixelStateManager.paletteManager else {
            return .transparent
        }

        // Primary 색상 인덱스 가져오기 (없으면 추가)
        var primaryIndex = paletteManager.findExactColorIndex(primaryColor)
        if primaryIndex == nil {
            primaryIndex = paletteManager.addColor(primaryColor)
            #if DEBUG
            if let idx = primaryIndex {
                print("➕ Added Primary color to palette[\(idx)]")
            } else {
                print("⚠️ Failed to add Primary color to palette (palette full)")
            }
            #endif
        }

        // Secondary 색상 인덱스 가져오기 (없으면 추가)
        var secondaryIndex = paletteManager.findExactColorIndex(secondaryColor)
        if secondaryIndex == nil {
            secondaryIndex = paletteManager.addColor(secondaryColor)
            #if DEBUG
            if let idx = secondaryIndex {
                print("➕ Added Secondary color to palette[\(idx)]")
            } else {
                print("⚠️ Failed to add Secondary color to palette (palette full)")
            }
            #endif
        }

        guard let startIdx = primaryIndex, let endIdx = secondaryIndex else {
            #if DEBUG
            print("❌ Failed to add gradient colors to palette (palette full)")
            #endif
            // Fallback: 가장 가까운 색상 사용
            let fallbackStart = paletteManager.findClosestColorIndex(primaryColor) ?? 0
            let fallbackEnd = paletteManager.findClosestColorIndex(secondaryColor) ?? 1
            return .paletteGradient(PaletteGradientPixel(
                startIndex: fallbackStart,
                endIndex: fallbackEnd,
                position: 0.5
            ))
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

        // paletteGradient 픽셀 생성 (중간색은 팔레트에 추가 안함!)
        return .paletteGradient(PaletteGradientPixel(
            startIndex: startIdx,
            endIndex: endIdx,
            position: position
        ))
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

        guard y >= 0, y < pixels.count, x >= 0, x < pixels[y].count else {
            print("❌ Out of bounds")
            return
        }
        let targetValue = pixels[y][x]

        // Phase 1: Fill 영역 찾기
        var fillArea: [(x: Int, y: Int)] = []
        var tempStack = [(x: Int, y: Int)]()
        var tempVisited = Set<String>()
        tempStack.append((x, y))
        tempVisited.insert("\(x),\(y)")

        while !tempStack.isEmpty {
            let point = tempStack.removeLast()
            let px = point.x, py = point.y

            guard px >= 0 && px < canvas.canvas.width && py >= 0 && py < canvas.canvas.height else { continue }
            guard py < pixels.count, px < pixels[py].count else { continue }
            if pixels[py][px] != targetValue { continue }

            fillArea.append((px, py))

            for (nx, ny) in [(px+1, py), (px-1, py), (px, py+1), (px, py-1)] {
                let key = "\(nx),\(ny)"
                if !tempVisited.contains(key) {
                    tempVisited.insert(key)
                    tempStack.append((nx, ny))
                }
            }
        }

        print("✓ Fill 영역: \(fillArea.count)개 픽셀")

        // Phase 2: 사용자가 드래그한 범위 그대로 사용 (자동 확장 안함)
        // 드래그 범위 밖은 시작색/끝색으로 채워짐

        // Phase 3: Fill 실행
        var changedPixels: [PixelChange] = []
        var oldPixels: [PixelChange] = []

        for (px, py) in fillArea {
            let fillValue = createGradientFillValue(at: px, y: py)
            oldPixels.append(PixelChange(x: px, y: py, value: targetValue))
            changedPixels.append(PixelChange(x: px, y: py, value: fillValue))
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

            print("✅ Gradient fill COMPLETE: \(changedPixels.count) pixels\n")
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
