//
//  TimelineViewModel+Selection.swift
//  Pixapper
//
//  Created by Claude on 2025-12-11.
//

import Foundation

// MARK: - Frame Selection Extension
extension TimelineViewModel {

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

    func selectFrame(at index: Int, clearSelection: Bool = true) {
        guard index < totalFrames else { return }
        currentFrameIndex = index

        if clearSelection {
            selectedFrameIndices = [index]
        }

        loadFrame(at: index)
    }
}
