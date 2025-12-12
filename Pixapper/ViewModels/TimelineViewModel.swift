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

    var playbackTimer: Timer?  // fileprivate for extension access
    let canvasWidth: Int
    let canvasHeight: Int

    var layerViewModel: LayerViewModel

    // 성능 최적화: totalFrames 계산 캐싱
    private var cachedMaxFrameIndex: Int?

    init(width: Int, height: Int, layerViewModel: LayerViewModel) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.layerViewModel = layerViewModel
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
        // 캐시가 있으면 재계산 스킵
        if let cached = cachedMaxFrameIndex {
            totalFrames = max(totalFrames, cached + 1)
            return
        }

        // 캐시가 없으면 계산 후 저장
        let maxIndex = layerViewModel.layers.map { $0.timeline.maxFrameIndex }.max() ?? 0
        cachedMaxFrameIndex = maxIndex
        totalFrames = max(totalFrames, maxIndex + 1)  // 현재 totalFrames와 maxIndex + 1 중 큰 값 사용
    }

    /// 현재 작업 중인 레이어의 픽셀을 소속 키프레임에 저장 (CanvasViewModel에서 호출)
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

        totalFrames += 1
        currentFrameIndex = insertIndex
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
        updateTotalFrames()

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
            updateTotalFrames()
        }
    }

    /// 키프레임 내용 지우기
    func clearFrameContent(frameIndex: Int, layerId: UUID) {
        guard frameIndex < totalFrames,
              let layerIndex = layerViewModel.layers.firstIndex(where: { $0.id == layerId }) else { return }

        let emptyPixels = createEmptyPixels()
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

        let emptyPixels = createEmptyPixels()
        layerViewModel.layers[layerIndex].timeline.setKeyframe(at: frameIndex, pixels: emptyPixels)

        updateTotalFrames()

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

    deinit {
        playbackTimer?.invalidate()
    }
}
