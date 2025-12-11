//
//  TimelineViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

@MainActor
class TimelineViewModel: ObservableObject {
    @Published var totalFrames: Int = 1  // Frame 배열 대신 개수만 관리
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var settings = AnimationSettings()

    // 다중 선택 지원
    @Published var selectedFrameIndices: Set<Int> = []  // 선택된 프레임들
    @Published var selectionAnchor: Int?  // 드래그/범위 선택 시작점

    private var playbackTimer: Timer?
    let canvasWidth: Int
    let canvasHeight: Int

    var layerViewModel: LayerViewModel

    init(width: Int, height: Int, layerViewModel: LayerViewModel) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.layerViewModel = layerViewModel
    }

    /// 모든 레이어의 최대 프레임 인덱스를 기준으로 totalFrames를 자동 업데이트
    func updateTotalFrames() {
        let maxIndex = layerViewModel.layers.map { $0.timeline.maxFrameIndex }.max() ?? 0
        totalFrames = max(totalFrames, maxIndex + 1)  // 현재 totalFrames와 maxIndex + 1 중 큰 값 사용
    }

    /// 현재 작업 중인 레이어의 픽셀을 소속 키프레임에 저장 (CanvasViewModel에서 호출)
    func syncCurrentLayerToKeyframe() {
        guard currentFrameIndex < totalFrames else { return }

        for layerIndex in layerViewModel.layers.indices {
            let layer = layerViewModel.layers[layerIndex]

            // 현재 프레임이 속한 키프레임 찾기
            if let owningKeyframe = layer.timeline.getOwningKeyframe(at: currentFrameIndex) {
                // 소속 키프레임에 현재 픽셀 저장
                layerViewModel.layers[layerIndex].timeline.setKeyframe(at: owningKeyframe, pixels: layer.pixels)
            } else {
                // 키프레임이 없으면 현재 프레임을 새 키프레임으로 생성
                layerViewModel.layers[layerIndex].timeline.setKeyframe(at: currentFrameIndex, pixels: layer.pixels)
            }
        }

        // 레이어별 키프레임 변경 후 totalFrames 자동 업데이트
        updateTotalFrames()
    }

    // MARK: - Frame Management

    /// 프레임 슬롯 삽입 (전역 동작) - Deprecated
    /// - Note: 더 이상 사용되지 않음. 레이어별 독립적인 키프레임 관리를 위해
    ///         각 레이어의 timeline.shiftKeyframes()를 직접 호출하세요.
    @available(*, deprecated, message: "Use layer-specific shiftKeyframes instead")
    private func insertFrameSlot(at insertIndex: Int) {
        if insertIndex >= totalFrames {
            // 끝에 추가
            totalFrames = insertIndex + 1
        } else {
            // 중간 삽입: 모든 레이어의 키프레임 인덱스를 +1 이동
            for i in layerViewModel.layers.indices {
                layerViewModel.layers[i].timeline.shiftKeyframes(after: insertIndex - 1, by: 1)
            }
            totalFrames += 1
        }
    }

    @available(*, deprecated, message: "Use addKeyframeWithContent or addBlankKeyframeAtNext instead")
    func addFrame() {
        // Deprecated: 대신 addKeyframeWithContent 또는 addBlankKeyframeAtNext 사용
        totalFrames += 1
        currentFrameIndex = currentFrameIndex + 1
        loadFrame(at: currentFrameIndex)
    }

    /// 프레임 슬롯 전체 삭제 (전역 동작)
    /// - Note: 모든 레이어의 해당 프레임 위치를 삭제하고, 뒤의 키프레임들을 앞으로 당깁니다.
    ///         Flash/Animate의 "Remove Frame" 기능과 동일합니다.
    func deleteFrame(at index: Int) {
        guard totalFrames > 1 && index < totalFrames else { return }

        // 각 레이어에서 해당 프레임의 키프레임 제거 및 이후 키프레임 인덱스 재조정
        for layerIndex in layerViewModel.layers.indices {
            if layerViewModel.layers[layerIndex].timeline.isKeyframe(at: index) {
                layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: index)
            }

            // index 이후의 모든 키프레임을 -1 인덱스로 이동
            layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: index, by: -1)
        }

        totalFrames -= 1
        if currentFrameIndex >= totalFrames {
            currentFrameIndex = totalFrames - 1
        }
        updateTotalFrames()
        loadFrame(at: currentFrameIndex)
    }

    /// 프레임 전체 복제 (전역 동작)
    /// - Note: 현재 화면(모든 레이어 합성본)을 복제하여 다음 위치에 프레임 슬롯을 생성합니다.
    ///         모든 레이어의 키프레임이 shift되며, Flash/Animate의 "Duplicate Frame" 기능과 동일합니다.
    func duplicateFrame(at index: Int) {
        guard index < totalFrames else { return }

        let insertIndex = index + 1

        // 각 레이어의 effective 픽셀을 복사하여 index 다음에 키프레임 삽입
        for layerIndex in layerViewModel.layers.indices {
            // 중요: shiftKeyframes 전에 복제할 픽셀을 먼저 가져와야 함!
            // shiftKeyframes 후에 가져오면 이미 이동된 키프레임을 참조하게 되어 데이터 손실 발생
            let pixelsToInsert = layerViewModel.layers[layerIndex].timeline.getEffectivePixels(at: index)

            // index 이후의 키프레임들을 +1로 이동
            layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: index, by: 1)

            // insertIndex에 새 키프레임 추가
            if let pixels = pixelsToInsert {
                layerViewModel.layers[layerIndex].timeline.setKeyframe(at: insertIndex, pixels: pixels)
            }
        }

        totalFrames += 1
        currentFrameIndex = insertIndex
        updateTotalFrames()
        loadFrame(at: insertIndex)
    }

    func selectFrame(at index: Int, clearSelection: Bool = true) {
        guard index < totalFrames else { return }
        currentFrameIndex = index

        if clearSelection {
            selectedFrameIndices = [index]
        }

        loadFrame(at: index)
    }

    // MARK: - Layer-Specific Frame Operations

    /// 현재 레이어에 키프레임 추가 (현재 그림 포함)
    /// - Note: 현재 레이어에만 영향을 주며, 다른 레이어는 변경되지 않음
    func addKeyframeWithContent() {
        let layerIndex = layerViewModel.selectedLayerIndex
        guard layerIndex < layerViewModel.layers.count else { return }

        // 현재 레이어의 픽셀을 미리 저장
        let currentPixels = layerViewModel.layers[layerIndex].pixels

        // 현재 프레임 다음에 삽입할 위치
        let insertIndex = currentFrameIndex + 1

        // 현재 레이어의 insertIndex 이후 키프레임만 shift (다른 레이어는 영향 없음)
        layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: currentFrameIndex, by: 1)

        // 현재 레이어의 픽셀을 새 키프레임으로 저장
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: insertIndex, pixels: currentPixels)

        // 새 프레임으로 이동
        currentFrameIndex = insertIndex

        // totalFrames 자동 업데이트
        updateTotalFrames()
        loadFrame(at: insertIndex)
    }

    /// 현재 레이어의 키프레임 span을 1프레임 연장 (현재 레이어의 뒤 키프레임들을 밀어냄)
    func extendCurrentKeyframeSpan() {
        let layerIndex = layerViewModel.selectedLayerIndex
        guard layerIndex < layerViewModel.layers.count else { return }

        let layer = layerViewModel.layers[layerIndex]

        // 현재 프레임이 속한 키프레임 span 찾기
        guard let span = layer.timeline.getKeyframeSpan(at: currentFrameIndex, totalFrames: totalFrames) else {
            return
        }

        let spanEnd = span.start + span.length - 1

        // 현재 레이어의 spanEnd 이후 키프레임들만 +1 이동 (다른 레이어는 건드리지 않음!)
        let allKeyframeIndices = layer.timeline.getAllKeyframeIndices()
        let hasNextKeyframes = allKeyframeIndices.contains(where: { $0 > spanEnd })

        layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: spanEnd, by: 1)

        // 마지막 키프레임인 경우 키프레임 없이 span만 확장
        if !hasNextKeyframes {
            layerViewModel.layers[layerIndex].timeline.setSpanEnd(at: spanEnd + 1)
        }

        // totalFrames 자동 업데이트
        updateTotalFrames()
        loadFrame(at: currentFrameIndex)
    }

    /// 현재 레이어에 빈 키프레임 추가
    /// - Note: 현재 레이어에만 영향을 주며, 다른 레이어는 변경되지 않음
    func addBlankKeyframeAtNext() {
        let layerIndex = layerViewModel.selectedLayerIndex
        guard layerIndex < layerViewModel.layers.count else { return }

        // 빈 픽셀 미리 생성
        let emptyPixels = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)

        // 현재 프레임 다음에 삽입할 위치
        let insertIndex = currentFrameIndex + 1

        // 현재 레이어의 insertIndex 이후 키프레임만 shift (다른 레이어는 영향 없음)
        layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: currentFrameIndex, by: 1)

        // 빈 픽셀로 새 키프레임 생성
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: insertIndex, pixels: emptyPixels)

        // 새 프레임으로 이동
        currentFrameIndex = insertIndex

        // totalFrames 자동 업데이트
        updateTotalFrames()
        loadFrame(at: insertIndex)
    }

    // MARK: - Frame Selection

    /// 단일 프레임 선택 (기존 선택 해제)
    func selectSingleFrame(at index: Int) {
        guard index < totalFrames else { return }
        selectedFrameIndices = [index]
        currentFrameIndex = index
        selectionAnchor = index
        loadFrame(at: index)
    }

    /// 프레임 범위 선택
    func selectFrameRange(from start: Int, to end: Int) {
        let range = min(start, end)...max(start, end)
        selectedFrameIndices = Set(range.filter { $0 < totalFrames })

        // 현재 프레임은 마지막 선택된 프레임으로
        if let last = selectedFrameIndices.max() {
            currentFrameIndex = last
            loadFrame(at: last)
        }
    }

    /// 프레임 선택 토글 (Cmd+클릭)
    func toggleFrameSelection(at index: Int) {
        guard index < totalFrames else { return }

        if selectedFrameIndices.contains(index) {
            selectedFrameIndices.remove(index)
            // 선택 해제 시 다른 프레임으로 이동
            if !selectedFrameIndices.isEmpty {
                currentFrameIndex = selectedFrameIndices.max() ?? 0
            } else {
                // 모든 선택 해제 시 selectionAnchor도 초기화
                selectionAnchor = nil
            }
        } else {
            selectedFrameIndices.insert(index)
            currentFrameIndex = index
        }

        loadFrame(at: currentFrameIndex)
    }

    /// 선택 해제
    func clearFrameSelection() {
        selectedFrameIndices.removeAll()
        selectionAnchor = nil
    }

    /// 모든 프레임 선택
    func selectAllFrames() {
        selectedFrameIndices = Set(0..<totalFrames)
        selectionAnchor = 0
    }

    /// 드래그로 범위 선택
    func updateDragSelection(from startIndex: Int, to currentIndex: Int) {
        let range = min(startIndex, currentIndex)...max(startIndex, currentIndex)
        selectedFrameIndices = Set(range.filter { $0 < totalFrames })
    }

    func loadFrame(at index: Int) {
        guard index < totalFrames else { return }

        // 각 레이어의 timeline에서 effective 픽셀 로드
        for layerIndex in layerViewModel.layers.indices {
            if let effectivePixels = layerViewModel.layers[layerIndex].timeline.getEffectivePixels(at: index) {
                layerViewModel.layers[layerIndex].pixels = effectivePixels
            } else {
                // 키프레임이 없으면 빈 픽셀로 초기화
                let emptyPixels = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)
                layerViewModel.layers[layerIndex].pixels = emptyPixels
            }
        }
    }

    // MARK: - Keyframe Operations

    /// 키프레임 토글
    func toggleKeyframe(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        if layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex) {
            // 키프레임 제거
            layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: frameIndex)
        } else {
            // 키프레임으로 변환 (현재 보이는 픽셀 데이터를 복사)
            if let effectivePixels = layerViewModel.layers[layerIndex].timeline.getEffectivePixels(at: frameIndex) {
                layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: effectivePixels)
            } else {
                // 이전 키프레임이 없으면 빈 키프레임 생성
                let emptyPixels = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)
                layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: emptyPixels)
            }
        }

        updateTotalFrames()

        // UI 갱신을 위해 프레임 재로드
        if frameIndex == currentFrameIndex {
            loadFrame(at: currentFrameIndex)
        }
    }

    /// 프레임 연장 (F5): 현재 span 끝에 프레임 추가
    func extendFrame(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        // span 정보 가져오기
        if let span = layerViewModel.layers[layerIndex].timeline.getKeyframeSpan(at: frameIndex, totalFrames: totalFrames) {
            let spanEnd = span.start + span.length - 1

            // span 끝 다음에 프레임이 있고 키프레임이면, 제거하여 연장
            if spanEnd + 1 < totalFrames && layerViewModel.layers[layerIndex].timeline.isKeyframe(at: spanEnd + 1) {
                layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: spanEnd + 1)
            }
        }
    }

    /// 키프레임 내용 지우기
    func clearFrameContent(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        let emptyPixels = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: emptyPixels)

        updateTotalFrames()

        if frameIndex == currentFrameIndex {
            layerViewModel.layers[layerIndex].pixels = emptyPixels
        }
    }

    /// 기존 프레임을 빈 키프레임으로 변환 (F7)
    /// - Note: 새 프레임을 추가하지 않고, 기존 프레임을 빈 키프레임으로 설정합니다
    func insertBlankKeyframe(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        let emptyPixels = Array(repeating: Array(repeating: nil as Color?, count: canvasWidth), count: canvasHeight)
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: emptyPixels)

        updateTotalFrames()

        if frameIndex == currentFrameIndex {
            layerViewModel.layers[layerIndex].pixels = emptyPixels
        }
    }

    // MARK: - Helper Methods

    /// 특정 프레임의 유효한 픽셀 반환 (TimelinePanel에서 사용)
    func getEffectivePixels(frameIndex: Int, layerId: UUID) -> [[Color?]]? {
        guard let layer = layerViewModel.layers.first(where: { $0.id == layerId }) else { return nil }
        return layer.timeline.getEffectivePixels(at: frameIndex)
    }

    /// Flash 스타일: 키프레임 span 계산
    func getKeyframeSpan(frameIndex: Int, layerId: UUID) -> (start: Int, length: Int)? {
        guard let layer = layerViewModel.layers.first(where: { $0.id == layerId }) else { return nil }
        return layer.timeline.getKeyframeSpan(at: frameIndex, totalFrames: totalFrames)
    }

    /// 셀이 키프레임 span의 어느 위치인지 반환
    enum FrameSpanPosition {
        case keyframeStart
        case extended
        case end
        case empty
    }

    func getFrameSpanPosition(frameIndex: Int, layerId: UUID) -> FrameSpanPosition {
        guard frameIndex < totalFrames,
              let layer = layerViewModel.layers.first(where: { $0.id == layerId }) else { return .empty }

        // 키프레임인지 확인
        if layer.timeline.isKeyframe(at: frameIndex) {
            return .keyframeStart
        }

        // span 정보 가져오기
        guard let span = layer.timeline.getKeyframeSpan(at: frameIndex, totalFrames: totalFrames) else {
            return .empty
        }

        // span의 마지막인지 확인
        if frameIndex == span.start + span.length - 1 {
            return .end
        }

        return .extended
    }

    // MARK: - Playback

    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            startPlayback()
        } else {
            stopPlayback()
        }
    }

    func play() {
        isPlaying = true
        startPlayback()
    }

    func pause() {
        isPlaying = false
        stopPlayback()
    }

    private func startPlayback() {
        stopPlayback()

        let interval = settings.frameDuration
        playbackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.advanceFrame()
            }
        }
        if let timer = playbackTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func advanceFrame() {
        if currentFrameIndex < totalFrames - 1 {
            currentFrameIndex += 1
        } else if settings.isLooping {
            currentFrameIndex = 0
        } else {
            pause()
            return
        }
        loadFrame(at: currentFrameIndex)
    }

    func nextFrame() {
        if currentFrameIndex < totalFrames - 1 {
            currentFrameIndex += 1
            loadFrame(at: currentFrameIndex)
        }
    }

    func previousFrame() {
        if currentFrameIndex > 0 {
            currentFrameIndex -= 1
            loadFrame(at: currentFrameIndex)
        }
    }

    // MARK: - Settings

    func setFPS(_ fps: Int) {
        settings.fps = fps
        if isPlaying {
            startPlayback()
        }
    }

    func setPlaybackSpeed(_ speed: Double) {
        settings.playbackSpeed = speed
        if isPlaying {
            startPlayback()
        }
    }

    func toggleLoop() {
        settings.isLooping.toggle()
    }

    func toggleOnionSkin() {
        settings.onionSkinEnabled.toggle()
    }

    // MARK: - Onion Skin Helpers

    func getOnionSkinFrames() -> [(frameIndex: Int, tint: Color, opacity: Double)] {
        var result: [(frameIndex: Int, tint: Color, opacity: Double)] = []

        if !settings.onionSkinEnabled {
            return result
        }

        // Previous frames (red tint)
        for i in 1...settings.onionSkinPrevFrames {
            let frameIndex = currentFrameIndex - i
            if frameIndex >= 0 && frameIndex < totalFrames {
                let opacity = settings.onionSkinOpacity / Double(i)
                result.append((frameIndex, .red, opacity))
            }
        }

        // Next frames (blue tint)
        for i in 1...settings.onionSkinNextFrames {
            let frameIndex = currentFrameIndex + i
            if frameIndex >= 0 && frameIndex < totalFrames {
                let opacity = settings.onionSkinOpacity / Double(i)
                result.append((frameIndex, .blue, opacity))
            }
        }

        return result
    }

    /// Export용: 모든 키프레임 로직이 적용된 프레임 배열 반환
    func getResolvedFrames() -> [Frame] {
        return (0..<totalFrames).map { frameIndex in
            var cells: [CellData] = []

            for layer in layerViewModel.layers {
                if let effectivePixels = layer.timeline.getEffectivePixels(at: frameIndex) {
                    let cell = CellData(pixels: effectivePixels, layerId: layer.id, isKeyframe: layer.timeline.isKeyframe(at: frameIndex))
                    cells.append(cell)
                } else {
                    // 키프레임이 없으면 빈 셀
                    let emptyCell = CellData(width: canvasWidth, height: canvasHeight, layerId: layer.id, isKeyframe: false)
                    cells.append(emptyCell)
                }
            }

            return Frame(cells: cells)
        }
    }

    deinit {
        playbackTimer?.invalidate()
    }
}
