//
//  Constants.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/10/25.
//

import Foundation

/// 프로젝트 전역 상수
enum Constants {
    /// 캔버스 기본 설정
    enum Canvas {
        /// 기본 캔버스 너비 (픽셀)
        static let defaultWidth = 32
        /// 기본 캔버스 높이 (픽셀)
        static let defaultHeight = 32
    }

    /// Command Manager 설정
    enum CommandManager {
        /// Undo/Redo 히스토리 최대 크기
        static let maxHistorySize = 100
    }

    /// UI 레이아웃 설정
    enum Layout {
        /// Timeline 패널 레이아웃
        enum Timeline {
            /// 레이어 컬럼 너비
            static let layerColumnWidth: CGFloat = 180
            /// 프레임 셀 크기 (더 조밀한 타임라인)
            static let cellSize: CGFloat = 48
        }
    }
}
