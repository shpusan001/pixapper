//
//  LayerViewModel.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/9/25.
//

import SwiftUI
import Combine

/// LayerViewModel - 레이어 컬렉션을 관리합니다
///
/// ## 책임 (Responsibilities)
/// 1. **레이어 배열 관리**: 추가, 삭제, 복제, 이동, 이름 변경
/// 2. **레이어 속성 관리**: 가시성, 투명도
/// 3. **선택된 레이어 추적**: selectedLayerIndex
///
/// ## TimelineViewModel과의 관계
/// - LayerViewModel은 TimelineViewModel을 **알지 못합니다** (의존하지 않음)
/// - TimelineViewModel이 LayerViewModel을 참조하여 프레임 전환 시 픽셀을 업데이트합니다
/// - 단방향 의존성: TimelineViewModel → LayerViewModel
///
/// ## 중요 사항
/// - Layer.pixels는 **현재 프레임의 캐시**입니다
/// - 실제 타임라인 데이터는 **Layer.timeline**에 키프레임 형태로 저장됩니다
/// - 픽셀 변경 후 반드시 `TimelineViewModel.syncCurrentLayerToKeyframe()`을 호출해야 합니다
@MainActor
class LayerViewModel: ObservableObject {
    @Published var layers: [Layer]
    @Published var selectedLayerIndex: Int = 0

    private let canvasWidth: Int
    private let canvasHeight: Int

    init(width: Int, height: Int) {
        self.canvasWidth = width
        self.canvasHeight = height
        self.layers = [Layer(name: "Layer 1", width: width, height: height)]
    }

    func addLayer() {
        let newLayer = Layer(name: "Layer \(layers.count + 1)", width: canvasWidth, height: canvasHeight)
        layers.append(newLayer)
        selectedLayerIndex = layers.count - 1
    }

    func deleteLayer(at index: Int) {
        guard layers.count > 1 && index < layers.count else { return }
        layers.remove(at: index)
        if selectedLayerIndex >= layers.count {
            selectedLayerIndex = layers.count - 1
        }
    }

    func duplicateLayer(at index: Int) {
        guard index < layers.count else { return }
        let duplicatedLayer = layers[index].duplicate(newName: "\(layers[index].name) Copy")
        layers.insert(duplicatedLayer, at: index + 1)
        selectedLayerIndex = index + 1
    }

    func renameLayer(at index: Int, to newName: String) {
        guard index < layers.count else { return }
        layers[index].name = newName
    }

    func moveLayer(from source: IndexSet, to destination: Int) {
        layers.move(fromOffsets: source, toOffset: destination)
        // Update selected index after move
        if let sourceIndex = source.first {
            if sourceIndex < destination {
                selectedLayerIndex = destination - 1
            } else {
                selectedLayerIndex = destination
            }
        }
    }

    func toggleVisibility(at index: Int) {
        guard index < layers.count else { return }
        layers[index].isVisible.toggle()
    }

    func setOpacity(at index: Int, opacity: Double) {
        guard index < layers.count else { return }
        layers[index].opacity = opacity
    }
}
