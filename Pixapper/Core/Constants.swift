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

    /// Adobe 스타일 프로페셔널 UI 색상
    enum Theme {
        /// 메인 배경 (가장 어두운 영역 - 캔버스 주변)
        static let backgroundDark = SwiftUI.Color(red: 0.18, green: 0.18, blue: 0.18) // #2E2E2E

        /// 패널 배경 (툴바, 사이드 패널)
        static let panelBackground = SwiftUI.Color(red: 0.22, green: 0.22, blue: 0.22) // #383838

        /// 섹션 배경 (그룹 영역, 카드)
        static let sectionBackground = SwiftUI.Color(red: 0.27, green: 0.27, blue: 0.27) // #454545

        /// 호버/활성 상태
        static let hoverBackground = SwiftUI.Color(red: 0.32, green: 0.32, blue: 0.32) // #525252

        /// 구분선
        static let divider = SwiftUI.Color(red: 0.15, green: 0.15, blue: 0.15) // #262626

        /// 선택/액센트 블루
        static let accentBlue = SwiftUI.Color(red: 0.25, green: 0.53, blue: 0.96) // #4087F5

        /// 액센트 블루 호버
        static let accentBlueHover = SwiftUI.Color(red: 0.33, green: 0.61, blue: 1.0) // #549CFF

        /// 주 텍스트 (밝은 회색)
        static let textPrimary = SwiftUI.Color(red: 0.9, green: 0.9, blue: 0.9) // #E6E6E6

        /// 보조 텍스트 (중간 회색)
        static let textSecondary = SwiftUI.Color(red: 0.65, green: 0.65, blue: 0.65) // #A6A6A6

        /// 비활성 텍스트 (어두운 회색)
        static let textDisabled = SwiftUI.Color(red: 0.45, green: 0.45, blue: 0.45) // #737373

        /// 타임라인 현재 프레임 인디케이터
        static let playheadRed = SwiftUI.Color(red: 0.95, green: 0.26, blue: 0.21) // #F24336

        /// 키프레임 다이아몬드
        static let keyframeDiamond = SwiftUI.Color(red: 0.35, green: 0.71, blue: 0.29) // #59B54A
    }

    /// Command Manager 설정
    enum CommandManager {
        /// Undo/Redo 히스토리 최대 크기
        static let maxHistorySize = 100
    }

    /// UI 레이아웃 설정
    enum Layout {
        /// 표준 스페이싱 스케일
        enum Spacing {
            /// Extra small - 최소 간격 (4pt)
            static let xs: CGFloat = 4
            /// Small - 작은 간격 (8pt)
            static let sm: CGFloat = 8
            /// Medium - 기본 간격 (12pt)
            static let md: CGFloat = 12
            /// Large - 큰 간격 (16pt)
            static let lg: CGFloat = 16
            /// Extra large - 패널/화면 패딩 (24pt)
            static let xl: CGFloat = 24
        }

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
            /// 프레임 셀 크기 (기본값)
            static let cellSize: CGFloat = 64
            /// 타임라인 행 높이 (헤더, 툴바 모두 동일)
            static let rowHeight: CGFloat = 32
            /// Playback 버튼 크기
            static let playbackButtonSize: CGFloat = 24
        }

        /// Tool 패널 레이아웃
        enum Tool {
            /// 도구 버튼 크기
            static let buttonSize: CGFloat = 44
        }

        /// UI 요소 크기
        enum UI {
            /// 체커보드 패턴 사각형 크기
            static let checkerboardSquareSize: CGFloat = 4

            /// 색상 관련 크기
            enum ColorSwatch {
                /// 기본 색상 셀 크기 (Recent, Palette)
                static let cellSize: CGFloat = 24
                /// 작은 색상 셀 크기 (Secondary)
                static let smallCellSize: CGFloat = 16
                /// Primary 색상 스와치 크기
                static let primarySize: CGFloat = 36
                /// 색상 간 간격
                static let spacing: CGFloat = 4
            }
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

    /// 선택 도구 설정
    enum Selection {
        /// 리사이즈 핸들 크기 (픽셀) - 클릭 판정 범위
        static let handleSize: CGFloat = 1.5
        /// 회전 핸들 크기 (픽셀) - 클릭 판정 범위
        static let rotateHandleSize: CGFloat = 1.5
        /// 회전 핸들과 선택 영역 간 거리 (픽셀)
        static let rotateHandleDistance: CGFloat = 3
        /// 복사-붙여넣기 시 오프셋 (픽셀)
        static let pasteOffset: Int = 10
    }

    /// PixelStateManager 설정
    enum PixelState {
        /// Timeline 동기화 debounce 시간 (초)
        static let syncDebounceInterval: TimeInterval = 0.1
    }
}
