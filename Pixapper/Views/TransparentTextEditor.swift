//
//  TransparentTextEditor.swift
//  Pixapper
//
//  Created by Claude on 2025-12-18.
//

import SwiftUI
import AppKit

/// 투명한 NSTextView 래퍼 - 엔터/백스페이스 완전 지원
struct TransparentTextEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var cursorPosition: Int
    var fontSize: CGFloat
    var textBoxWidth: CGFloat  // 텍스트 박스 너비 (픽셀 단위)
    var textBoxHeight: CGFloat  // 텍스트 박스 높이 (픽셀 단위)
    var onTextChange: () -> Void
    var onCancel: (() -> Void)?  // Escape 키 처리
    var onCommit: (() -> Void)?  // Cmd+Enter 또는 외부 클릭

    func makeNSView(context: Context) -> CustomTextView {
        // Frame 설정 - height는 충분히 크게 (자동 줄바꿈으로 늘어남)
        let textView = CustomTextView(frame: NSRect(x: 0, y: 0, width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude))

        textView.delegate = context.coordinator
        textView.onCancel = context.coordinator.handleCancel
        textView.onCommit = context.coordinator.handleCommit

        // 기본 설정
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true

        // 외관 설정
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.textColor = .clear  // 투명
        textView.insertionPointColor = .clear  // 커서도 투명 (픽셀로 렌더링)
        textView.string = text

        // 자동 치환 비활성화
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false

        // 자동 줄바꿈 설정 (텍스트 박스 크기 제한)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: textBoxWidth, height: 0)

        if let container = textView.textContainer {
            // 여백 제거 (중요!)
            container.lineFragmentPadding = 0

            // 컨테이너 크기 설정 (가로 고정, 세로 무제한)
            container.containerSize = NSSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude)
            container.widthTracksTextView = false
            container.heightTracksTextView = false
        }

        // 텍스트 레이아웃 관리자 설정
        if let layoutManager = textView.layoutManager {
            layoutManager.allowsNonContiguousLayout = false
        }

        return textView
    }

    func updateNSView(_ textView: CustomTextView, context: Context) {
        // 텍스트가 외부에서 변경되었을 때만 업데이트
        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            // 커서 위치 복원
            if selectedRange.location <= text.count {
                textView.setSelectedRange(selectedRange)
            }
        }

        // 폰트 크기 업데이트
        textView.font = NSFont.systemFont(ofSize: fontSize)

        // 텍스트 박스 크기 업데이트 (리사이즈 시)
        textView.frame = NSRect(x: 0, y: 0, width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.maxSize = NSSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: textBoxWidth, height: 0)

        if let container = textView.textContainer {
            container.containerSize = NSSize(width: textBoxWidth, height: CGFloat.greatestFiniteMagnitude)
        }

        // First responder 유지
        if textView.window?.firstResponder != textView {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: TransparentTextEditor

        init(_ parent: TransparentTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // 텍스트 업데이트
            parent.text = textView.string

            // 커서 위치 업데이트
            parent.cursorPosition = textView.selectedRange().location

            parent.onTextChange()
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }

            // 커서 위치 업데이트
            parent.cursorPosition = textView.selectedRange().location
        }

        func handleCancel() {
            parent.onCancel?()
        }

        func handleCommit() {
            parent.onCommit?()
        }
    }
}

/// 커스텀 NSTextView - 엔터/백스페이스 완전 지원
class CustomTextView: NSTextView {
    var onCancel: (() -> Void)?
    var onCommit: (() -> Void)?

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Escape - 취소
        if event.keyCode == 53 { // Escape
            onCancel?()
            return true
        }

        // Cmd+Enter - 커밋
        if event.keyCode == 36 && event.modifierFlags.contains(.command) { // Cmd+Return
            onCommit?()
            return true
        }

        // 엔터키 - 직접 처리 (단축키보다 우선)
        if event.keyCode == 36 { // Return
            if !event.modifierFlags.contains(.command) {
                self.insertText("\n", replacementRange: self.selectedRange())
                return true
            }
        }

        // 백스페이스 - 직접 처리
        if event.keyCode == 51 { // Delete (Backspace)
            self.deleteBackward(nil)
            return true
        }

        // 나머지는 기본 처리
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        // interpretKeyEvents를 통해 텍스트 편집 명령으로 자동 변환
        self.interpretKeyEvents([event])
    }

    override func insertNewline(_ sender: Any?) {
        // 엔터키 - 줄바꿈 삽입
        self.insertText("\n", replacementRange: self.selectedRange())
    }

    override func deleteBackward(_ sender: Any?) {
        // 백스페이스 - 이전 문자 삭제
        super.deleteBackward(sender)
    }
}
