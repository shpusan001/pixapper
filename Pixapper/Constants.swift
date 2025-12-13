//
//  Constants.swift
//  Pixapper
//
//  Created by LeeSangHoon on 12/10/25.
//

import Foundation
import SwiftUI

/// 프로젝트 전역 상수
enum Constants {
    /// 캔버스 기본 설정
    enum Canvas {
        /// 기본 캔버스 너비 (픽셀)
        static let defaultWidth = 32
        /// 기본 캔버스 높이 (픽셀)
        static let defaultHeight = 32
        /// 체커보드 패턴 밝은 회색
        static let checkerboardLightGray: CGFloat = 0.9
        /// 체커보드 패턴 어두운 회색
        static let checkerboardDarkGray: CGFloat = 0.8
        /// 캔버스 주변 최소 마진 (pt) - 선택 영역이 여유롭게 나갈 수 있도록
        static let minMargin: CGFloat = 500
    }

    /// 색상 관련 설정
    enum Color {
        /// 색상 비교 기본 허용 오차 (0.0 ~ 1.0)
        static let defaultTolerance: Double = 0.001
    }

    /// Command Manager 설정
    enum CommandManager {
        /// Undo/Redo 히스토리 최대 크기
        static let maxHistorySize = 100
    }

    /// UI 레이아웃 설정
    enum Layout {
        /// 패널 너비
        enum Panel {
            /// 레이어 패널 너비
            static let layerPanelWidth: CGFloat = 240
            /// 도구 패널 너비
            static let toolPanelWidth: CGFloat = 320
            /// Export 뷰 너비
            static let exportViewWidth: CGFloat = 400
        }

        /// Timeline 패널 레이아웃
        enum Timeline {
            /// 레이어 컬럼 너비
            static let layerColumnWidth: CGFloat = 180
            /// 프레임 셀 크기 (더 조밀한 타임라인)
            static let cellSize: CGFloat = 48
            /// 프레임 헤더 행 높이
            static let frameHeaderHeight: CGFloat = 26
            /// Playback 버튼 크기
            static let playbackButtonSize: CGFloat = 24
        }

        /// Tool 패널 레이아웃
        enum Tool {
            /// 도구 버튼 크기
            static let buttonSize: CGFloat = 44
        }
    }

    /// 애니메이션 설정
    enum Animation {
        /// 기본 FPS
        static let defaultFPS: Int = 12
        /// 기본 재생 속도 배율
        static let defaultPlaybackSpeed: Double = 1.0
        /// 기본 루프 설정
        static let defaultLooping: Bool = true
        /// Onion skin 기본 활성화 여부
        static let defaultOnionSkinEnabled: Bool = false
        /// Onion skin 이전 프레임 개수
        static let defaultOnionSkinPrevFrames: Int = 1
        /// Onion skin 다음 프레임 개수
        static let defaultOnionSkinNextFrames: Int = 1
        /// Onion skin 투명도
        static let defaultOnionSkinOpacity: Double = 0.3
    }

    /// UI 투명도 설정
    enum Opacity {
        /// Canvas 관련
        enum Canvas {
            /// 그리드 라인 opacity
            static let gridLine: Double = 0.3
            /// Shape 미리보기 opacity
            static let shapePreview: Double = 0.5
        }

        /// Timeline 관련
        enum Timeline {
            /// 선택된 레이어 배경 opacity
            static let selectedLayerBackground: Double = 0.15
            /// 드래그 중인 레이어 배경 opacity
            static let draggingLayerBackground: Double = 0.25
            /// 범위 밖 프레임 배경 opacity
            static let outOfRangeBackground: Double = 0.5
            /// 키프레임 배경 opacity
            static let keyframeBackground: Double = 0.5
            /// Extended span 배경 opacity
            static let extendedSpanBackground: Double = 0.25
        }
    }
}
