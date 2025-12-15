# Pixapper - 아키텍처 가이드

> 픽셀 아트 애니메이션 에디터의 표준 아키텍처 문서

## 📁 프로젝트 구조

```
Pixapper/
├── Core/                          # 앱 진입점 및 전역 설정
│   ├── PixapperApp.swift          # 앱 진입점
│   └── Constants.swift            # 전역 상수 (UI, Animation 등)
│
├── Models/                        # 데이터 모델
│   ├── Core/                      # 핵심 도메인 모델
│   │   ├── PixelCanvas.swift      # 캔버스 데이터
│   │   ├── Layer.swift            # 레이어 모델
│   │   ├── Frame.swift            # 프레임/타임라인 모델
│   │   └── FrameClipboard.swift   # 프레임 클립보드
│   ├── Commands/                  # Command 패턴 구현
│   │   ├── Command.swift          # Command 프로토콜
│   │   ├── Drawing/               # 그리기 명령
│   │   ├── Layer/                 # 레이어 조작 명령
│   │   ├── Timeline/              # 타임라인 조작 명령
│   │   └── Selection/             # 선택 영역 명령
│   ├── Tools/                     # 도구 설정 모델
│   └── Serialization/             # 직렬화 지원
│
├── ViewModels/                    # MVVM - 비즈니스 로직
│   ├── AppViewModel.swift         # 앱 전체 상태 관리
│   ├── CanvasViewModel.swift      # 캔버스 렌더링 로직
│   ├── LayerViewModel.swift       # 레이어 관리
│   ├── TimelineViewModel.swift    # 타임라인/애니메이션 관리
│   ├── CommandManager.swift       # Undo/Redo 시스템
│   ├── PixelStateManager.swift    # 픽셀 상태 관리 (SSOT)
│   ├── PlaybackController.swift   # 애니메이션 재생 제어
│   ├── ToolSettingsManager.swift  # 도구 설정 관리
│   └── Tools/                     # 도구 구현
│       ├── BaseTool.swift         # 공통 기반 클래스
│       ├── CanvasTool.swift       # 도구 프로토콜
│       ├── PencilEraserTool.swift # 연필/지우개
│       ├── FillTool.swift         # 채우기
│       ├── ShapeTool.swift        # 도형
│       └── SelectionTool.swift    # 선택/변형
│
├── Views/                         # SwiftUI UI 컴포넌트
│   ├── ContentView.swift          # 메인 레이아웃
│   ├── CanvasView.swift           # 캔버스 렌더링
│   ├── TimelinePanel.swift        # 타임라인 패널
│   ├── LayerPanel.swift           # 레이어 패널
│   ├── ToolPanel.swift            # 도구 패널
│   ├── PropertiesPanel.swift      # 속성 패널
│   ├── ExportView.swift           # 내보내기 뷰
│   └── FrameCellView.swift        # 프레임 셀
│
├── Services/                      # 외부 서비스
│   ├── ProjectManager.swift       # 프로젝트 파일 관리
│   └── ExportManager.swift        # PNG/GIF 내보내기
│
└── Extensions/                    # Swift 확장
    └── Color+Extensions.swift     # 색상 유틸리티
```

---

## 🏗️ 아키텍처 패턴

### MVVM (Model-View-ViewModel)
```
View (SwiftUI) ←→ ViewModel (@Published) ←→ Model
```

### 핵심 패턴

#### 1. **Command 패턴** - Undo/Redo
모든 편집 작업은 `Command` 프로토콜을 구현합니다.

```swift
protocol Command {
    func execute()
    func undo()
    var description: String { get }
}
```

**예시:**
- `DrawCommand` - 픽셀 그리기
- `AddLayerCommand` - 레이어 추가
- `ToggleKeyframeCommand` - 키프레임 토글

**장점:**
- 모든 작업 되돌리기 가능
- 히스토리 추적
- 테스트 용이

#### 2. **Single Source of Truth (SSOT)** - 픽셀 상태 관리
`PixelStateManager`가 모든 픽셀 데이터를 중앙 집중식으로 관리합니다.

```
도구가 픽셀 수정 요청
    ↓
PixelStateManager가 검증 및 적용
    ↓
자동으로 UI 업데이트 (@Published)
    ↓
debounce 후 Timeline에 동기화
```

**책임:**
- 현재 프레임 픽셀 캐시 관리
- 모든 픽셀 읽기/쓰기 중개
- Timeline 자동 동기화

#### 3. **책임 분리** - ViewModel 구조

```
AppViewModel (최상위)
  ├── CanvasViewModel (캔버스 렌더링)
  ├── LayerViewModel (레이어 관리)
  ├── TimelineViewModel (타임라인/애니메이션)
  │     ├── PlaybackController (재생 제어)
  │     └── PixelStateManager (픽셀 상태)
  ├── CommandManager (Undo/Redo)
  └── ToolSettingsManager (도구 설정)
```

**의존성 방향:**
- TimelineViewModel → LayerViewModel (단방향)
- LayerViewModel은 TimelineViewModel을 모름
- 순환 참조 방지

---

## 🎨 핵심 데이터 흐름

### 1. 프레임 전환 시

```swift
// 사용자가 프레임 5로 이동
timelineViewModel.loadFrame(at: 5)
    ↓
// 각 레이어의 타임라인에서 프레임 5의 픽셀 조회
layer.timeline.getEffectivePixels(at: 5)
    ↓
// PixelStateManager 캐시 업데이트
pixelStateManager.loadFrame(at: 5, layers: layers)
    ↓
// UI 자동 업데이트 (@Published)
```

### 2. 그리기 작업 시

```swift
// 1. 도구가 픽셀 변경
pencilTool.handleDown(x: 10, y: 15)
    ↓
// 2. TimelineViewModel을 통해 픽셀 설정
timelineViewModel.setPixel(layerId: id, x: 10, y: 15, color: .red)
    ↓
// 3. PixelStateManager가 캐시 업데이트
pixelStateManager.setPixel(...)
    ↓
// 4. UI 자동 업데이트 + debounce
@Published currentFramePixels 변경
    ↓
// 5. 100ms 후 Timeline에 동기화
pixelStateManager.syncToTimeline()
    ↓
// 6. 스트로크 완료 시 Command 생성
commandManager.addExecutedCommand(DrawCommand(...))
```

### 3. Undo/Redo 실행 시

```swift
// Cmd+Z (Undo)
commandManager.undo()
    ↓
// 가장 최근 Command의 undo() 호출
lastCommand.undo()
    ↓
// 이전 픽셀 상태로 복원
timelineViewModel.applyPixelChanges(layerId: id, changes: oldPixels)
    ↓
// PixelStateManager 업데이트
pixelStateManager.applyPixelChanges(...)
    ↓
// UI 자동 업데이트
```

---

## 🛠️ 도구 시스템

### 계층 구조

```swift
BaseTool (공통 의존성 + 헬퍼)
    ↑
    ├─ PencilEraserTool (그리기/지우개)
    ├─ FillTool (채우기)
    ├─ ShapeTool (도형)
    └─ SelectionTool (선택/변형)
         ↑
      CanvasTool 프로토콜
```

### BaseTool의 역할
- 공통 의존성 관리 (canvasViewModel, layerViewModel 등)
- 중복 코드 제거 (currentLayerIndex, currentLayerId)
- 일관된 초기화 패턴

### CanvasTool 프로토콜
```swift
protocol CanvasTool {
    func handleDown(x: Int, y: Int, altPressed: Bool)
    func handleDrag(x: Int, y: Int)
    func handleUp(x: Int, y: Int)
    func updateHover(x: Int, y: Int)  // 선택적
    func clearHover()                  // 선택적
    func handleOutsideClick()          // 선택적
}
```

---

## ⚙️ 설정 시스템

### Constants.swift - 전역 상수 관리

모든 하드코딩된 값은 `Constants` enum으로 중앙화:

```swift
Constants.Canvas.defaultWidth         // 32
Constants.Animation.defaultFPS        // 12
Constants.Selection.handleSize        // 1
Constants.PixelState.syncDebounceInterval  // 0.1초
```

**카테고리:**
- `Canvas` - 캔버스 설정
- `Color` - 색상 허용 오차
- `Animation` - FPS, Onion skin
- `Layout` - UI 크기
- `Opacity` - 투명도
- `Selection` - 선택 도구
- `PixelState` - 동기화 설정

---

## 🧪 확장 가이드

### 새로운 도구 추가

1. `BaseTool`을 상속하고 `CanvasTool` 채택
2. 필요한 상태 변수 추가
3. `handleDown/Drag/Up` 구현
4. `ToolType` enum에 추가
5. `ToolSettingsManager`에 설정 추가

### 새로운 Command 추가

1. `Command` 프로토콜 구현
2. `execute()`와 `undo()` 정의
3. 필요한 상태 백업 (undo용)
4. 일관된 패턴 사용:
   ```swift
   guard let timelineViewModel = timelineViewModel,
         let layerIndex = timelineViewModel.getLayerIndex(for: layerId) else {
       return
   }
   ```

### 새로운 View 추가

1. SwiftUI View 생성
2. `@ObservedObject`로 필요한 ViewModel 주입
3. CLAUDE.md의 UI 가이드라인 준수
4. 시스템 컬러/폰트 사용

---

## 📊 성능 최적화

### 1. Debouncing
- 연속 그리기 중: UI만 업데이트
- 100ms 후: Timeline 동기화
- 불필요한 timeline 저장 방지

### 2. 캐싱
- `PixelStateManager`가 현재 프레임 캐시
- `TimelineViewModel`의 `cachedMaxFrameIndex`
- 중복 계산 방지

### 3. Lazy Rendering
- SwiftUI의 LazyVStack/LazyHStack 활용
- 필요한 프레임만 렌더링

---

## 🔒 메모리 관리

### Weak 참조 패턴
```swift
// ViewModel → ViewModel
weak var timelineViewModel: TimelineViewModel?

// Command → ViewModel
private weak var timelineViewModel: TimelineViewModel?

// Tool → ViewModel
weak var canvasViewModel: CanvasViewModel?
```

**이유:** 순환 참조 방지

### Strong 참조
```swift
// 부모가 소유
let layerViewModel: LayerViewModel
let commandManager: CommandManager
```

---

## 🚀 빌드 & 테스트

```bash
# Debug 빌드
xcodebuild -scheme Pixapper -configuration Debug build

# Release 빌드
xcodebuild -scheme Pixapper -configuration Release build
```

---

## 📝 코딩 컨벤션

### 네이밍
- **클래스/구조체**: PascalCase (`PixelCanvas`)
- **변수/함수**: camelCase (`currentFrameIndex`)
- **상수**: static let (`defaultWidth`)
- **프로토콜**: 명사 또는 -able (`CanvasTool`, `Identifiable`)

### 주석
- `///` DocC 스타일 주석 사용
- `MARK:` 섹션 구분
- 복잡한 로직에만 주석 (자명한 코드는 주석 불필요)

### 파일 구조
```swift
// MARK: - Dependencies
// MARK: - Published State
// MARK: - Initialization
// MARK: - Public Methods
// MARK: - Private Methods
// MARK: - Helper Methods
```

---

## 📚 참고 자료

- **CLAUDE.md** - UI 디자인 가이드라인
- **Apple HIG** - macOS 디자인 가이드
- **Swift API Design Guidelines** - 네이밍 규칙

---

**마지막 업데이트:** 2025-12-14
**작성자:** Claude & 개발팀
