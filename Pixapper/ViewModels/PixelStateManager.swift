//
//  PixelStateManager.swift
//  Pixapper
//
//  Created by Claude on 2025-12-14.
//

import SwiftUI
import Combine

/// 픽셀 상태를 중앙 집중식으로 관리하는 매니저 (Single Source of Truth)
/// - Note: Reactive + State Manager 패턴 조합
///   - 모든 픽셀 읽기/쓰기는 이 클래스를 통해서만 수행
///   - @Published로 UI 자동 업데이트
///   - Timeline과 자동 동기화
@MainActor
class PixelStateManager: ObservableObject {
    // MARK: - Published State

    /// 현재 프레임의 모든 레이어 픽셀 (Single Source of Truth)
    /// - Key: Layer ID
    /// - Value: 픽셀 배열 PixelGrid
    @Published private(set) var currentFramePixels: [UUID: PixelGrid] = [:]

    /// 현재 프레임 인덱스 (읽기 전용)
    @Published private(set) var currentFrameIndex: Int = 0

    // MARK: - Dependencies

    private weak var layerViewModel: LayerViewModel?
    let paletteManager: PaletteManager
    private let canvasWidth: Int
    private let canvasHeight: Int
    private var paletteCancellable: AnyCancellable?

    /// 현재 팔레트 (편의 접근자)
    var currentPalette: ColorPalette {
        get { paletteManager.currentPalette }
        set { paletteManager.currentPalette = newValue }
    }

    // MARK: - Performance Optimization

    /// Dirty tracking - 변경된 레이어만 timeline에 동기화
    private var dirtyLayers: Set<UUID> = []

    /// Debounce timer - 빠른 연속 변경 시 성능 최적화
    private var syncTimer: Timer?

    // MARK: - Initialization

    init(canvasWidth: Int, canvasHeight: Int, layerViewModel: LayerViewModel, paletteManager: PaletteManager = PaletteManager()) {
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.layerViewModel = layerViewModel
        self.paletteManager = paletteManager

        // PaletteManager의 변경사항을 PixelStateManager에 전파
        self.paletteCancellable = paletteManager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Public API: 읽기

    /// 특정 레이어의 현재 프레임 픽셀 가져오기
    /// - Parameter layerId: 레이어 ID
    /// - Returns: 픽셀 배열 (캐싱됨, O(1) 조회)
    func getPixels(layerId: UUID) -> PixelGrid? {
        return currentFramePixels[layerId]
    }

    /// 특정 레이어의 단일 픽셀 값 가져오기
    /// - Parameters:
    ///   - layerId: 레이어 ID
    ///   - x: X 좌표
    ///   - y: Y 좌표
    /// - Returns: 픽셀 값 (.transparent = 투명)
    func getPixel(layerId: UUID, x: Int, y: Int) -> PixelValue? {
        guard let pixels = currentFramePixels[layerId],
              y >= 0, y < pixels.count,
              x >= 0, x < pixels[y].count else {
            return nil
        }
        return pixels[y][x]
    }

    // MARK: - Public API: 쓰기

    /// 단일 픽셀 수정 (즉시 캐시 업데이트 + debounced timeline 동기화)
    /// - Parameters:
    ///   - layerId: 레이어 ID
    ///   - x: X 좌표
    ///   - y: Y 좌표
    ///   - value: 픽셀 값 (.transparent = 투명)
    func setPixel(layerId: UUID, x: Int, y: Int, value: PixelValue) {
        guard var pixels = currentFramePixels[layerId],
              y >= 0, y < pixels.count,
              x >= 0, x < pixels[y].count else {
            return
        }

        // 캐시 즉시 업데이트
        pixels[y][x] = value
        currentFramePixels[layerId] = pixels

        // Force UI update (SwiftUI doesn't always detect nested array changes)
        objectWillChange.send()

        // Dirty tracking
        dirtyLayers.insert(layerId)

        // Timeline 동기화 스케줄 (debounced)
        scheduleSyncToTimeline()
    }

    /// 대량 픽셀 변경 (Command용 - 배치 처리)
    /// - Parameters:
    ///   - layerId: 레이어 ID
    ///   - changes: 픽셀 변경 배열
    func applyPixelChanges(layerId: UUID, changes: [PixelChange]) {
        guard var pixels = currentFramePixels[layerId] else { return }

        // 대량 변경 적용
        for change in changes {
            guard change.y >= 0, change.y < pixels.count,
                  change.x >= 0, change.x < pixels[change.y].count else {
                continue
            }
            pixels[change.y][change.x] = change.value
        }

        // 캐시 업데이트
        currentFramePixels[layerId] = pixels

        // Force UI update (SwiftUI doesn't always detect nested array changes)
        objectWillChange.send()

        // Dirty tracking
        dirtyLayers.insert(layerId)

        // Timeline 즉시 동기화 (Command는 debounce 하지 않음)
        syncToTimelineImmediate()
    }

    /// 전체 픽셀 배열 설정 (프레임 전환 등에 사용)
    /// - Parameters:
    ///   - layerId: 레이어 ID
    ///   - pixels: 픽셀 배열
    func setAllPixels(layerId: UUID, pixels: PixelGrid) {
        currentFramePixels[layerId] = pixels
        dirtyLayers.insert(layerId)
    }

    // MARK: - Frame Management

    /// 프레임 로드 (timeline에서 모든 레이어 픽셀 로드)
    /// - Parameter frameIndex: 로드할 프레임 인덱스
    func loadFrame(at frameIndex: Int) {
        guard let layerVM = layerViewModel else { return }

        currentFrameIndex = frameIndex

        let emptyPixels = createEmptyPixels()
        var newState: [UUID: PixelGrid] = [:]

        // 모든 레이어의 픽셀을 timeline에서 로드
        for layer in layerVM.layers {
            let pixels = layer.timeline.getEffectivePixels(at: frameIndex) ?? emptyPixels
            newState[layer.id] = pixels
        }

        // 상태 업데이트 (Reactive - @Published가 UI 자동 업데이트)
        currentFramePixels = newState

        // Dirty 상태 초기화
        dirtyLayers.removeAll()
    }

    /// 현재 프레임을 timeline에 강제 동기화
    func syncToTimeline() {
        syncToTimelineImmediate()
    }

    // MARK: - Private Methods

    /// Timeline 동기화 스케줄 (debounced)
    /// - Note: 연속 그리기 중에는 UI만 업데이트하고, 멈추면 timeline에 동기화
    private func scheduleSyncToTimeline() {
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: Constants.PixelState.syncDebounceInterval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.syncToTimelineImmediate()
            }
        }
    }

    /// Timeline 즉시 동기화 (dirty layers만)
    /// - Note: Adobe Animate 방식
    ///   - Extended 프레임 수정 → owning keyframe 업데이트
    ///   - 빈 프레임 수정 → 자동으로 새 키프레임 생성
    private func syncToTimelineImmediate() {
        guard let layerVM = layerViewModel else { return }

        for layerId in dirtyLayers {
            guard let layerIndex = layerVM.layers.firstIndex(where: { $0.id == layerId }),
                  let pixels = currentFramePixels[layerId] else {
                continue
            }

            // 현재 프레임이 속한 키프레임 찾기
            if let owningKeyframe = layerVM.layers[layerIndex].timeline.getOwningKeyframe(at: currentFrameIndex) {
                // Extended 프레임: owning keyframe 업데이트
                // (현재 프레임이 키프레임이면 owningKeyframe == currentFrameIndex)
                layerVM.layers[layerIndex].timeline.setKeyframe(
                    at: owningKeyframe,
                    pixels: pixels
                )
            } else {
                // 빈 프레임: 새 키프레임 생성 (Adobe Animate 방식)
                layerVM.layers[layerIndex].timeline.setKeyframe(
                    at: currentFrameIndex,
                    pixels: pixels
                )
            }

            // Layer.pixels도 동기화 (기존 코드 호환성)
            layerVM.layers[layerIndex].pixels = pixels
        }

        dirtyLayers.removeAll()
    }

    /// 빈 픽셀 배열 생성
    private func createEmptyPixels() -> PixelGrid {
        return Layer.createEmptyPixels(width: canvasWidth, height: canvasHeight)
    }

    /// 레이어 추가/삭제 시 호출 (상태 재동기화)
    func invalidateState() {
        loadFrame(at: currentFrameIndex)
    }

    // MARK: - Color Usage Analysis

    /// 현재 프레임에서 각 색상 인덱스의 사용 횟수 계산
    /// - Returns: [색상 인덱스: 사용 횟수] 딕셔너리
    func getColorUsage() -> [UInt8: Int] {
        var usage: [UInt8: Int] = [:]

        // 모든 레이어의 픽셀을 순회
        for pixels in currentFramePixels.values {
            for row in pixels {
                for pixel in row {
                    if case .indexed(let index) = pixel {
                        usage[index, default: 0] += 1
                    }
                }
            }
        }

        return usage
    }
}
