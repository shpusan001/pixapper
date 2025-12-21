//
//  ClipboardManager.swift
//  Pixapper
//
//  통합된 클립보드 관리
//  선택 영역과 프레임 클립보드를 중앙에서 관리합니다
//

import SwiftUI
import Combine

// MARK: - Clipboard Content Types

/// 클립보드에 저장될 수 있는 콘텐츠 타입
enum ClipboardContent {
    case selection(SelectionClipboard)
    case frames(FrameClipboard)
    case empty

    var isEmpty: Bool {
        switch self {
        case .empty:
            return true
        case .frames(let frameClipboard):
            return frameClipboard.isEmpty
        case .selection:
            return false
        }
    }

    var isSelection: Bool {
        if case .selection = self { return true }
        return false
    }

    var isFrames: Bool {
        if case .frames = self { return true }
        return false
    }
}

// MARK: - Clipboard Manager

/// 앱 전체의 클립보드를 중앙에서 관리하는 매니저
/// - Note: 선택 영역(SelectionClipboard)과 프레임(FrameClipboard)을 통합 관리
class ClipboardManager: ObservableObject {
    // MARK: - Shared Instance

    static let shared = ClipboardManager()

    // MARK: - Published Properties

    @Published private(set) var content: ClipboardContent = .empty

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 클립보드에 콘텐츠를 복사합니다
    /// - Parameter content: 복사할 콘텐츠 (선택 영역 또는 프레임)
    func copy(_ content: ClipboardContent) {
        self.content = content
    }

    /// 클립보드의 현재 콘텐츠를 반환합니다
    /// - Returns: 클립보드 콘텐츠 (없으면 .empty)
    func paste() -> ClipboardContent {
        return content
    }

    /// 클립보드를 비웁니다
    func clear() {
        content = .empty
    }

    // MARK: - Computed Properties

    /// 클립보드에 콘텐츠가 있는지 확인
    var hasContent: Bool {
        return !content.isEmpty
    }

    /// 선택 영역 클립보드가 있는지 확인
    var hasSelectionClipboard: Bool {
        return content.isSelection
    }

    /// 프레임 클립보드가 있는지 확인
    var hasFrameClipboard: Bool {
        return content.isFrames
    }

    // MARK: - Typed Getters

    /// 선택 영역 클립보드를 가져옵니다
    /// - Returns: SelectionClipboard 또는 nil
    func getSelectionClipboard() -> SelectionClipboard? {
        if case .selection(let clipboard) = content {
            return clipboard
        }
        return nil
    }

    /// 프레임 클립보드를 가져옵니다
    /// - Returns: FrameClipboard 또는 nil
    func getFrameClipboard() -> FrameClipboard? {
        if case .frames(let clipboard) = content {
            return clipboard
        }
        return nil
    }
}

// MARK: - Convenience Methods

extension ClipboardManager {
    /// 선택 영역을 복사합니다
    func copySelection(pixels: PixelGrid, width: Int, height: Int) {
        let clipboard = SelectionClipboard(pixels: pixels, width: width, height: height)
        copy(.selection(clipboard))
    }

    /// 프레임을 복사합니다
    func copyFrames(frameCount: Int, keyframes: [Int: PixelGrid], sourceLayerId: UUID? = nil) {
        let clipboard = FrameClipboard(frameCount: frameCount, keyframes: keyframes, sourceLayerId: sourceLayerId)
        copy(.frames(clipboard))
    }
}
