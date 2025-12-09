# CLAUDE.md - Mac App Development Guide

## UI Design Principles

### Native First
- SwiftUI 기본 컴포넌트 우선 사용
- AppKit 필요시만 선택적 사용
- 시스템 폰트 (SF Pro) 기본값 유지
- 시스템 컬러 팔레트 활용

### Color System
```swift
// Semantic colors - 자동 다크/라이트 대응
Color.primary          // 메인 텍스트
Color.secondary        // 서브 텍스트
Color.accentColor      // 액션 버튼, 하이라이트
Color(nsColor: .controlBackgroundColor)  // 배경
Color(nsColor: .separatorColor)          // 구분선
```

### Spacing Scale
```swift
4pt  // xs - 아이콘 패딩
8pt  // sm - 최소 간격
12pt // md - 기본 간격
16pt // lg - 섹션 간격
24pt // xl - 화면 패딩
```

### Typography
```swift
.title      // 20pt, Bold - 화면 제목
.headline   // 17pt, Semibold - 섹션 헤더
.body       // 13pt, Regular - 기본 텍스트
.callout    // 12pt, Regular - 서브 정보
.caption    // 11pt, Regular - 보조 텍스트
```

### Component Guidelines

**Buttons**
- Primary: `.buttonStyle(.borderedProminent)`
- Secondary: `.buttonStyle(.bordered)`
- Text only: `.buttonStyle(.plain)`

**Lists**
- `List` with `.listStyle(.sidebar)` for navigation
- `List` with `.listStyle(.inset)` for content

**Windows**
- 기본 크기: 800x600 ~ 1200x800
- 최소 크기 명시: `.frame(minWidth: 600, minHeight: 400)`

### Dark/Light Mode
```swift
// 자동 대응하는 시스템 컬러만 사용
// 커스텀 컬러 필요시:
Color("CustomColor") // Assets.xcassets에서 Appearances 설정
```

## Project Structure
```
YourApp/
├── Views/          # UI 컴포넌트
├── ViewModels/     # 비즈니스 로직
├── Models/         # 데이터 모델
├── Services/       # API, Storage 등
└── Resources/      # Assets, Localizations
```

## Extensions
### Performance
- LazyVStack/LazyHStack 사용 (리스트 성능)
- `@StateObject`, `@ObservedObject` 적절히 구분
- heavy 작업은 `Task { }` 로 비동기 처리

### Accessibility
```swift
.accessibilityLabel("설명")
.accessibilityHint("동작 힌트")
```

### Keyboard Shortcuts
```swift
.keyboardShortcut("n", modifiers: .command)
```

---

# 개발 기조
- 복잡성은 낮게 하려고 노력해
- 기능 변경이나 추가할 때 전체 프로젝트 일관성을 먼저 고려해
