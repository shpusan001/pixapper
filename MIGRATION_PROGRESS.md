# 팔레트 시스템 마이그레이션 진행 상황

## 목표
Color 기반 → PixelValue 기반 팔레트 인덱스 시스템 전환

## 핵심 타입 변경
- `[[Color?]]` → `PixelGrid` (= `[[PixelValue]]`)
- `Color?` → `PixelValue`
- PixelValue enum: `.transparent`, `.indexed(UInt8)`, `.gradient(UUID)`

---

## Phase 1: 핵심 자료구조 ✅ 완료

### 신규 파일 생성 완료
- [x] PixelValue.swift - 확장 가능한 픽셀 타입
- [x] ColorPalette.swift - 팔레트 관리
- [x] GradientLibrary.swift - 그라디언트 라이브러리
- [x] RenderContext.swift - 렌더링 컨텍스트

### 기존 파일 수정 완료
- [x] Layer.swift - pixels: PixelGrid
- [x] Frame.swift - keyframes: [Int: PixelGrid]

---

## Phase 2: Command 파일 수정 ✅ 완료

### Timeline Commands ✅
- [x] CutFramesCommand.swift
- [x] DeleteFrameCommand.swift
- [x] DeleteFramesCommand.swift
- [x] ExtendFrameCommand.swift
- [x] InsertBlankKeyframeCommand.swift
- [x] PasteFramesCommand.swift
- [x] AddKeyframeWithContentCommand.swift
- [x] AddBlankKeyframeCommand.swift
- [x] ToggleKeyframeCommand.swift
- [x] ClearFrameContentCommand.swift

### Selection Commands ✅
- [x] SelectionCommitCommand.swift
- [x] SelectionCaptureCommand.swift
- [x] SelectionMoveCommand.swift
- [x] SelectionTransformCommand.swift
- [x] PasteCommand.swift

---

## Phase 3: ViewModel 수정 ✅ 완료

### 상태 관리
- [x] PixelStateManager.swift - currentFramePixels: [UUID: PixelGrid]
- [x] TimelineViewModel.swift - 픽셀 접근 API 수정
- [x] LayerViewModel.swift - 레이어 픽셀 처리
- [x] CanvasViewModel.swift - 드로잉 컨텍스트 통합

### 색상 관리
- [x] ColorManager.swift - 팔레트 기능 강화

---

## Phase 4: Tool 수정 ✅ 완료

### 기본 도구
- [x] BaseTool.swift - DrawingContext 사용
- [x] PencilEraserTool.swift
- [x] FillTool.swift
- [x] ShapeTool.swift

### 고급 도구
- [x] MirrorTool.swift
- [x] DitheringTool.swift
- [x] TextTool.swift
- [x] SelectionTool.swift
- [x] SymmetryTool.swift

---

## Phase 5: 렌더링 및 Export ✅ 완료

- [x] ExportManager.swift - PixelValue → Color 변환
- [x] CanvasView.swift - 렌더링 통합 (PixelGridView, OnionSkinLayerView, SelectionRectView)
- [x] FrameCellView.swift - 썸네일 렌더링
- [x] TimelineComponents.swift - CellThumbnailView

---

## Phase 6: 직렬화

- [ ] ProjectDocument.swift - v1.2 버전 추가
- [ ] SerializableLayer.swift - PixelGrid 직렬화
- [ ] SemanticVersion.swift - v1.2 추가

---

## 빌드 에러 추적

### 현재 에러 개수: 0개 ✅
**BUILD SUCCEEDED** - 모든 타입 변환 완료!

---

## 작업 노트

### 2025-12-19
- ✅ Phase 1 핵심 자료구조 완료
  - PixelValue, ColorPalette, GradientLibrary, RenderContext 생성
  - Layer, Frame 타입 변경 완료

- ✅ Phase 2 Command 파일 수정 완료
  - Timeline Commands (11개) 완료
  - Selection Commands (5개) 완료
  - FrameClipboard, SelectionState 타입 변경 완료

- ✅ Phase 3 ViewModel 수정 완료
  - PixelStateManager, TimelineViewModel, CanvasViewModel 완료
  - SelectionTool 메서드 시그니처 업데이트 완료
  - ExportManager 렌더링 로직 업데이트 완료

- ✅ Phase 4 Tool 수정 완료
  - ShapeTool, TextTool, DitheringTool, FillTool, MirrorTool, PencilEraserTool 완료
  - SelectionTool 완료 (31개 에러 모두 해결)

- ✅ Phase 5 View 파일 수정 완료
  - FrameCellView 썸네일 렌더링 업데이트
  - TimelineComponents.swift - CellThumbnailView 업데이트
  - CanvasView.swift - PixelGridView, OnionSkinLayerView, SelectionRectView 완료

- ✅ **최종 빌드 성공!**
  - 모든 타입 변환 완료: [[Color?]] → PixelGrid
  - 빌드 에러 0개
  - Phase 1~5 완료 (Phase 6 직렬화는 향후 작업)
