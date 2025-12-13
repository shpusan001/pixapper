//
//  TimelineViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

/// 타임라인 프레임 정보 (UI 업데이트를 위한 Identifiable 구조체)
struct FrameInfo: Identifiable {
    let id = UUID()
    let index: Int
}

/// TimelineViewModel - 타임라인과 애니메이션 상태를 관리합니다
///
/// ## 책임 (Responsibilities)
/// 1. **프레임 관리**: 총 프레임 수, 현재 프레임 인덱스 관리
/// 2. **애니메이션 재생**: 재생/정지, FPS 기반 타이머 제어
/// 3. **프레임 전환 조정**: `loadFrame()`을 통해 레이어 픽셀 동기화
/// 4. **키프레임 동기화**: 현재 레이어 상태를 키프레임에 저장
///
/// ## LayerViewModel과의 관계
/// - TimelineViewModel은 LayerViewModel을 **읽고** Layer.timeline에 **접근**할 수 있습니다
/// - LayerViewModel.layers 배열을 직접 수정하여 픽셀을 업데이트합니다
/// - LayerViewModel은 TimelineViewModel을 알지 못합니다 (단방향 의존성)
///
/// ## 데이터 흐름
/// ```
/// 사용자가 프레임 변경
///   ↓
/// TimelineViewModel.loadFrame(at: index)
///   ↓
/// 각 Layer.timeline.getEffectivePixels(at: index)로 키프레임 조회
///   ↓
/// LayerViewModel.layers[i].pixels = 조회된 픽셀 (캐시 업데이트)
///   ↓
/// UI 자동 업데이트 (@Published)
/// ```
@MainActor
class TimelineViewModel: ObservableObject {
    @Published var totalFrames: Int = 1  // Frame 배열 대신 개수만 관리
    @Published var frames: [FrameInfo] = []  // UI 업데이트를 위한 프레임 배열
    @Published var currentFrameIndex: Int = 0
    @Published var isPlaying: Bool = false
    @Published var settings = AnimationSettings()

    // 다중 선택 지원
    @Published var selectedFrameIndices: Set<Int> = []  // 선택된 프레임들
    @Published var selectionAnchor: Int?  // 드래그/범위 선택 시작점

    // 프레임 클립보드 (복사/붙여넣기)
    @Published var frameClipboard: FrameClipboard = .empty

    var playbackTimer: Timer?  // fileprivate for extension access
    var canvasWidth: Int
    var canvasHeight: Int

    /// LayerViewModel 참조 (읽기 및 수정 가능)
    /// - Note: TimelineViewModel이 프레임 전환 시 레이어 픽셀을 직접 업데이트합니다
    var layerViewModel: LayerViewModel

    // 성능 최적화: totalFrames 계산 캐싱
    private var cachedMaxFrameIndex: Int?

    init(width: Int, height: Int, layerViewModel: LayerViewModel) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.layerViewModel = layerViewModel

        // 초기 frames 배열 생성
        self.frames = (0..<totalFrames).map { FrameInfo(index: $0) }
    }

    // MARK: - Helper Methods

    /// 선택된 레이어 인덱스 검증
    private func validateSelectedLayer() -> Int? {
        let index = layerViewModel.selectedLayerIndex
        guard index >= 0 && index < layerViewModel.layers.count else { return nil }
        return index
    }

    /// 레이어 ID로 인덱스 찾기 (Command에서 자주 사용)
    func getLayerIndex(for layerId: UUID) -> Int? {
        return layerViewModel.layers.firstIndex(where: { $0.id == layerId })
    }

    /// 캐시 무효화 (레이어 변경 시 호출)
    func invalidateTotalFramesCache() {
        cachedMaxFrameIndex = nil
    }

    /// 모든 레이어의 최대 프레임 인덱스를 기준으로 totalFrames를 자동 업데이트
    func updateTotalFrames() {
        // 캐시가 없으면 계산 후 저장
        let maxIndex = layerViewModel.layers.map { $0.timeline.maxFrameIndex }.max() ?? 0
        let newTotalFrames = max(1, maxIndex + 1)

        // totalFrames가 실제로 변경된 경우에만 업데이트
        if totalFrames != newTotalFrames {
            totalFrames = newTotalFrames
            // frames 배열도 재생성 (SwiftUI가 변경사항 감지)
            regenerateFrames()
        }

        // 캐시 업데이트
        cachedMaxFrameIndex = maxIndex
    }

    /// frames 배열 재생성 (UI 업데이트 보장)
    private func regenerateFrames() {
        frames = (0..<totalFrames).map { FrameInfo(index: $0) }
    }

    /// 현재 작업 중인 레이어의 픽셀을 소속 키프레임에 저장
    /// - Note: 도구(Tool)가 픽셀을 변경한 후 이 메서드를 호출하여 변경사항을 키프레임에 영구 저장합니다
    /// - Important: Layer.pixels는 캐시이므로, 반드시 timeline.setKeyframe()으로 저장해야 합니다
    func syncCurrentLayerToKeyframe() {
        guard currentFrameIndex < totalFrames else { return }

        for layerIndex in layerViewModel.layers.indices {
            var layer = layerViewModel.layers[layerIndex]

            // 현재 프레임이 속한 키프레임 찾기
            let keyframeIndex = layer.timeline.getOwningKeyframe(at: currentFrameIndex) ?? currentFrameIndex
            layer.timeline.setKeyframe(at: keyframeIndex, pixels: layer.pixels)

            layerViewModel.layers[layerIndex] = layer
        }

        // 레이어별 키프레임 변경 후 캐시 무효화 및 totalFrames 자동 업데이트
        invalidateTotalFramesCache()
        updateTotalFrames()
    }

    // MARK: - Frame Management


    /// 프레임 슬롯 전체 삭제 (전역 동작)
    /// - Note: 모든 레이어의 해당 프레임 위치를 삭제하고, 뒤의 키프레임들을 앞으로 당깁니다.
    ///         Flash/Animate의 "Remove Frame" 기능과 동일합니다.
    func deleteFrame(at index: Int) {
        guard index < totalFrames && totalFrames > 1 else { return }

        // 각 레이어에서 해당 프레임의 키프레임 제거 및 이후 키프레임 인덱스 재조정
        for layerIndex in layerViewModel.layers.indices {
            if layerViewModel.layers[layerIndex].timeline.isKeyframe(at: index) {
                layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: index)
            }

            // index 이후의 모든 키프레임을 -1 인덱스로 이동
            layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: index, by: -1)
        }

        // totalFrames는 updateTotalFrames()에서 자동 계산
        updateTotalFrames()

        // 현재 프레임 인덱스 조정
        if currentFrameIndex >= totalFrames && totalFrames > 0 {
            currentFrameIndex = totalFrames - 1
        }

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

        // updateTotalFrames()가 totalFrames와 frames를 자동으로 업데이트
        currentFrameIndex = insertIndex
        invalidateTotalFramesCache()
        updateTotalFrames()
        loadFrame(at: insertIndex)
    }

    // MARK: - Layer-Specific Frame Operations

    /// 현재 레이어에 키프레임 추가 (현재 그림 포함)
    /// - Note: 현재 레이어에만 영향을 주며, 다른 레이어는 변경되지 않음
    func addKeyframeWithContent() {
        guard let layerIndex = validateSelectedLayer() else { return }

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
        guard let layerIndex = validateSelectedLayer() else { return }

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
        guard let layerIndex = validateSelectedLayer() else { return }

        // 빈 픽셀 미리 생성
        let emptyPixels = Layer.createEmptyPixels(width: canvasWidth, height: canvasHeight)

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

    /// 현재 레이어의 프레임 삭제 (레이어별 독립 동작)
    /// - Note: 현재 레이어의 해당 프레임만 제거하고 뒤의 키프레임들을 당깁니다.
    ///         다른 레이어는 영향을 받지 않습니다.
    func deleteFrameInCurrentLayer(at index: Int) {
        guard let layerIndex = validateSelectedLayer() else { return }

        let layer = layerViewModel.layers[layerIndex]

        // 해당 레이어에 키프레임이 하나라도 있는지 확인
        guard layer.timeline.keyframeCount > 0 else { return }

        // 해당 위치에 키프레임이 있으면 제거
        if layer.timeline.isKeyframe(at: index) {
            layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: index)
        } else {
            // 키프레임이 아닌 경우 (extended frame), span을 축소
            // index 이후에 다른 키프레임이 있는지 확인
            let hasKeyframesAfter = layer.timeline.getAllKeyframeIndices().contains(where: { $0 > index })

            if !hasKeyframesAfter {
                // index 이후에 키프레임이 없으면, span 끝을 축소
                layerViewModel.layers[layerIndex].timeline.shrinkSpanEnd(by: 1)
            }
        }

        // 현재 레이어의 index 이후 키프레임들을 -1로 이동
        layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: index, by: -1)

        // totalFrames 자동 업데이트 (다른 레이어가 더 길면 유지됨)
        updateTotalFrames()

        // 현재 프레임 인덱스 조정
        if currentFrameIndex >= totalFrames && totalFrames > 0 {
            currentFrameIndex = totalFrames - 1
        }

        loadFrame(at: currentFrameIndex)
    }

    /// 모든 레이어의 모든 프레임 크기를 변경합니다
    func resizeAllFrames(width: Int, height: Int) {
        canvasWidth = width
        canvasHeight = height

        // 모든 레이어의 모든 키프레임 크기 조정
        for layerIndex in layerViewModel.layers.indices {
            let keyframeIndices = layerViewModel.layers[layerIndex].timeline.getAllKeyframeIndices()

            for frameIndex in keyframeIndices {
                if let pixels = layerViewModel.layers[layerIndex].timeline.getKeyframe(at: frameIndex) {
                    // 기존 픽셀 크기
                    let oldHeight = pixels.count
                    let oldWidth = pixels.isEmpty ? 0 : pixels[0].count

                    // 새 크기로 픽셀 배열 생성
                    var newPixels = Layer.createEmptyPixels(width: width, height: height)

                    // 기존 픽셀 복사 (범위 내에서만)
                    for y in 0..<min(oldHeight, height) {
                        for x in 0..<min(oldWidth, width) {
                            newPixels[y][x] = pixels[y][x]
                        }
                    }

                    // 키프레임 업데이트
                    layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: newPixels)
                }
            }
        }
    }

    // MARK: - Frame Selection
    // Selection methods moved to TimelineViewModel+Selection.swift

    func loadFrame(at index: Int) {
        guard index < totalFrames else { return }

        let emptyPixels = createEmptyPixels()

        // 각 레이어의 timeline에서 effective 픽셀 로드
        for layerIndex in layerViewModel.layers.indices {
            let effectivePixels = layerViewModel.layers[layerIndex].timeline.getEffectivePixels(at: index) ?? emptyPixels
            layerViewModel.layers[layerIndex].pixels = effectivePixels
        }
    }

    // MARK: - Keyframe Operations

    /// 키프레임 토글
    func toggleKeyframe(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        var layer = layerViewModel.layers[layerIndex]

        if layer.timeline.isKeyframe(at: frameIndex) {
            // 키프레임 제거
            layer.timeline.removeKeyframe(at: frameIndex)
        } else {
            // 키프레임으로 변환 (현재 보이는 픽셀 데이터를 복사)
            let emptyPixels = createEmptyPixels()
            let effectivePixels = layer.timeline.getEffectivePixels(at: frameIndex) ?? emptyPixels
            layer.timeline.setKeyframe(at: frameIndex, pixels: effectivePixels)
        }

        layerViewModel.layers[layerIndex] = layer

        // 캐시 무효화 및 totalFrames 업데이트
        invalidateTotalFramesCache()
        updateTotalFrames()

        // UI 강제 갱신 (키프레임 상태 변경은 totalFrames를 바꾸지 않으므로)
        objectWillChange.send()

        // UI 갱신을 위해 프레임 재로드
        if frameIndex == currentFrameIndex {
            loadFrame(at: currentFrameIndex)
        }
    }

    /// 프레임 연장 (F5): 현재 span 끝에 프레임 추가
    func extendFrame(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }),
              let span = layerViewModel.layers[layerIndex].timeline.getKeyframeSpan(at: frameIndex, totalFrames: totalFrames) else {
            return
        }

        let spanEnd = span.start + span.length - 1
        let nextFrameIndex = spanEnd + 1

        // 범위 검증
        guard nextFrameIndex < totalFrames else { return }

        // span 끝 다음에 키프레임이 있으면 제거하여 연장
        if layerViewModel.layers[layerIndex].timeline.isKeyframe(at: nextFrameIndex) {
            layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: nextFrameIndex)
            invalidateTotalFramesCache()
            updateTotalFrames()
            objectWillChange.send()
        }
    }

    /// 키프레임 내용 지우기
    func clearFrameContent(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        let emptyPixels = createEmptyPixels()
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: emptyPixels)

        invalidateTotalFramesCache()
        updateTotalFrames()
        objectWillChange.send()

        if frameIndex == currentFrameIndex {
            layerViewModel.layers[layerIndex].pixels = emptyPixels
        }
    }

    /// 기존 프레임을 빈 키프레임으로 변환 (F7)
    /// - Note: 새 프레임을 추가하지 않고, 기존 프레임을 빈 키프레임으로 설정합니다
    func insertBlankKeyframe(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        let emptyPixels = createEmptyPixels()
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: emptyPixels)

        invalidateTotalFramesCache()
        updateTotalFrames()
        objectWillChange.send()

        if frameIndex == currentFrameIndex {
            layerViewModel.layers[layerIndex].pixels = emptyPixels
        }
    }

    // MARK: - Helper Methods

    /// 빈 픽셀 배열 생성 (중복 코드 제거)
    private func createEmptyPixels() -> [[Color?]] {
        return Layer.createEmptyPixels(width: canvasWidth, height: canvasHeight)
    }

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

    /// 프레임에 내용이 있는지 확인
    func hasFrameContent(frameIndex: Int, layerId: UUID) -> Bool {
        guard let pixels = getEffectivePixels(frameIndex: frameIndex, layerId: layerId) else {
            return false
        }
        return pixels.contains(where: { row in row.contains(where: { $0 != nil }) })
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
    // Playback methods moved to TimelineViewModel+Playback.swift

    // MARK: - Onion Skin Helpers
    // Onion Skin methods moved to TimelineViewModel+OnionSkin.swift

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

    // MARK: - Frame Selection

    /// 단일 프레임 선택 (기존 선택 해제)
    func selectSingleFrame(at index: Int) {
        guard index < totalFrames else { return }
        selectedFrameIndices = [index]
        currentFrameIndex = index
        selectionAnchor = index
        loadFrame(at: index)
    }

    /// 드래그로 범위 선택
    func updateDragSelection(from startIndex: Int, to currentIndex: Int) {
        let range = min(startIndex, currentIndex)...max(startIndex, currentIndex)
        selectedFrameIndices = Set(range.filter { $0 < totalFrames })
    }

    /// 프레임 선택 (Command에서 사용)
    func selectFrame(at index: Int, clearSelection: Bool = true) {
        guard index < totalFrames else { return }
        currentFrameIndex = index

        if clearSelection {
            selectedFrameIndices = [index]
        }

        loadFrame(at: index)
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

    func startPlayback() {
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

    func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    func advanceFrame() {
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

    // MARK: - Onion Skin

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

    // MARK: - Frame Clipboard Operations

    /// 선택된 프레임들을 클립보드에 복사
    /// - Parameters:
    ///   - frameIndices: 복사할 프레임 인덱스들
    ///   - layerId: 복사할 레이어 ID
    func copyFrames(frameIndices: Set<Int>, layerId: UUID) {
        guard !frameIndices.isEmpty,
              let layer = layerViewModel.layers.first(where: { $0.id == layerId }) else {
            return
        }

        // 프레임 인덱스를 정렬
        let sortedIndices = frameIndices.sorted()
        let firstIndex = sortedIndices.first!
        let frameCount = sortedIndices.count

        // 키프레임 데이터를 상대 인덱스로 저장
        var keyframes: [Int: [[Color?]]] = [:]

        for frameIndex in sortedIndices {
            if layer.timeline.isKeyframe(at: frameIndex),
               let pixels = layer.timeline.getKeyframe(at: frameIndex) {
                let relativeIndex = frameIndex - firstIndex
                keyframes[relativeIndex] = pixels
            }
        }

        // 클립보드에 저장
        frameClipboard = FrameClipboard(
            frameCount: frameCount,
            keyframes: keyframes,
            sourceLayerId: layerId
        )
    }

    /// 선택된 프레임들을 잘라내기 (복사 + 삭제)
    /// - Parameters:
    ///   - frameIndices: 잘라낼 프레임 인덱스들
    ///   - layerId: 잘라낼 레이어 ID
    func cutFrames(frameIndices: Set<Int>, layerId: UUID) {
        // 먼저 복사
        copyFrames(frameIndices: frameIndices, layerId: layerId)

        // 선택된 프레임들을 삭제 (역순으로 삭제해야 인덱스가 안 꼬임)
        let sortedIndices = frameIndices.sorted(by: >)

        guard let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        for frameIndex in sortedIndices {
            // 키프레임이면 삭제
            if layerViewModel.layers[layerIndex].timeline.isKeyframe(at: frameIndex) {
                layerViewModel.layers[layerIndex].timeline.removeKeyframe(at: frameIndex)
            }
        }

        // 프레임 삭제 후 키프레임 재정렬
        // 삭제된 프레임 개수만큼 뒤의 키프레임들을 앞으로 이동
        let firstDeletedIndex = sortedIndices.last!
        let deletedCount = sortedIndices.count

        // firstDeletedIndex 이후의 키프레임들을 -deletedCount만큼 이동
        layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: firstDeletedIndex - 1, by: -deletedCount)

        // span 끝도 축소
        layerViewModel.layers[layerIndex].timeline.shrinkSpanEnd(by: deletedCount)

        updateTotalFrames()
        loadFrame(at: currentFrameIndex)
    }

    /// 클립보드의 프레임들을 현재 선택된 레이어에 붙여넣기
    /// - Parameter startIndex: 붙여넣을 시작 인덱스
    func pasteFrames(at startIndex: Int, layerId: UUID) {
        guard !frameClipboard.isEmpty,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else {
            return
        }

        let frameCount = frameClipboard.frameCount

        // startIndex 이후의 키프레임들을 frameCount만큼 뒤로 이동
        layerViewModel.layers[layerIndex].timeline.shiftKeyframes(after: startIndex - 1, by: frameCount)

        // 클립보드의 키프레임들을 붙여넣기
        for (relativeIndex, pixels) in frameClipboard.keyframes {
            let targetIndex = startIndex + relativeIndex
            layerViewModel.layers[layerIndex].timeline.setKeyframe(at: targetIndex, pixels: pixels)
        }

        updateTotalFrames()

        // 붙여넣은 첫 번째 프레임으로 이동
        currentFrameIndex = startIndex
        loadFrame(at: startIndex)
    }

    /// 클립보드가 비어있지 않은지 확인
    var hasFrameClipboard: Bool {
        return !frameClipboard.isEmpty
    }

    deinit {
        playbackTimer?.invalidate()
    }
}
