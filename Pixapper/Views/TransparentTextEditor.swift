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

    func makeNSView(context: Context) -> CustomTextView {
        let textView = CustomTextView()

        textView.delegate = context.coordinator

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
        textView.maxSize = NSSize(width: textBoxWidth, height: textBoxHeight)
        textView.minSize = NSSize(width: textBoxWidth, height: textBoxHeight)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = false

        if let container = textView.textContainer {
            container.containerSize = NSSize(width: textBoxWidth, height: textBoxHeight)
            container.widthTracksTextView = false
            container.heightTracksTextView = false
            container.lineBreakMode = .byCharWrapping  // 문자 단위로 줄바꿈
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
    }
}

/// 커스텀 NSTextView - 엔터/백스페이스 완전 지원
class CustomTextView: NSTextView {
    override var acceptsFirstResponder: Bool {
        return true
    }

    override func becomeFirstResponder() -> Bool {
        return super.becomeFirstResponder()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
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
