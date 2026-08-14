# Sprint 1: Foundation & Capture→Shelf

## 구현 범위

네이티브 macOS 앱 뼈대가 빌드되고, 스크린샷(또는 시뮬레이션)이 Shelf 에 등장하는 핵심 루프의 출발점.

### 파일 목록
- `src/Types/ShelfItem.swift` — `ShelfItem`, `ItemCategory`, `ShelfItemStatus` (Sendable 값타입)
- `src/Types/ShelfItem.swift` 테스트 — `tests/TypesTests/ShelfItemTests.swift`
- `src/Config/AppPaths.swift` — 기본 경로(라이브러리/인덱스/감시폴더), `ConfigError`
- `src/Config/ShelfSettings.swift` — 호버 시간·히스토리 한도(기본값)
- `tests/ConfigTests/AppPathsTests.swift`
- `src/Repo/ShelfItemRepository.swift` — `protocol ShelfItemRepository`
- `src/Repo/FileShelfRepository.swift` — 파일+JSON 영속(메모리 폴백 포함), idempotent insert
- `tests/RepoTests/FileShelfRepositoryTests.swift`
- `src/Service/IntakePipeline.swift` — `protocol IntakePipeline` + 기본 구현(새 URL → ShelfItem → repo)
- `tests/ServiceTests/IntakePipelineTests.swift`
- `src/Runtime/ScreenshotWatcher.swift` — FSEvents/DispatchSource 폴더 감시(구성 가능 경로)
- `src/Runtime/ShelfCoordinator.swift` — 앱 상태(@Observable 호환)로 watcher→pipeline→repo 연결
- `tests/RuntimeTests/ScreenshotWatcherTests.swift`, `ShelfCoordinatorTests.swift`
- `App/Sources/SnapShelfApp.swift` — `@main` App 진입, 메뉴바 accessory(LSUIElement), ShelfCoordinator 주입
- `App/Sources/Shelf/ShelfPanelView.swift` — NSPanel 래퍼 / 우하단 고정 표면
- `App/Sources/Shelf/ShelfView.swift` — 항목 스택 + 빈 상태
- `App/Sources/Shelf/ShelfItemView.swift` — 썸네일 + 메타 + 등장 애니메이션(ANIMATION_SPEC §1)
- `App/Sources/Components/StatusBarMenu.swift` — "Open Shelf / Simulate Capture / Quit"

> 새 파일 추가마다 `npm run gen:project` 실행(Project.yml 동기화).

## Sprint Contract (GENERATOR ↔ EVALUATOR)

### GENERATOR가 완료해야 할 것 (코드 구현 + 자가 검증)
- [ ] 위 파일 전부 구현
- [ ] 단위 테스트: Types/Config/Repo/Service/Runtime 각 (AAA 패턴)
- [ ] Gate 1 통과: `npm run harness:lint` (레이어 위반 0건)
- [ ] Gate 2 통과: `xcodebuild build` (컴파일 오류 0건, `Any`/강제언래핑 없음)
- [ ] Gate 3 통과: `swiftlint lint --strict` (error 0건)
- [ ] Gate 4 통과: `xcodebuild test -enableCodeCoverage YES` (line ≥80%, 실패 0)
- [ ] Gate 5 통과: `xcodebuild build` (성공)
- [ ] 개발 빌드 실행 확인(빌드 산출물 존재)

### EVALUATOR가 검증할 것 (사용자 관점 동작)
- [ ] 빌드: `xcodebuild build` 성공 → `.app` 산출
- [ ] 실행: `open <app>` → 메뉴바에 SnapShelf 아이콘 노출(상주)
- [ ] Shelf 열기: 메뉴 → "Open Shelf" → 우하단 ShelfPanel 등장(초기 빈 상태)
- [ ] 핵심 동작: "Simulate Capture" → 테스트 이미지 생성/감지 → ShelfItem 등장 애니메이션
- [ ] 빈 상태 안내 문구 정상 표시("⌘⇧4 로 캡처하면 여기에 쌓입니다")
- [ ] 항목 메타(파일명/시간) 정상 표시
- [ ] 스크린샷(Playwright 대체): `screencapture` 로 Shelf 패널 캡처 → 상태 확인
- [ ] 통과 기준: "위 항목 전부 정상 — 메뉴바 앱이 실행되고 시뮬레이션 캡처가 Shelf 에 등장"

## 의존 Sprint
이전 Sprint: 없음 (첫 Sprint)

## 비고

- ⌘⇧4 시스템 연계는 폴더 감시로 처리(직접 키 후킹 아님). EVAL 편의용 "Simulate Capture" 액션 병행.
- 권한(TCC): 감시 폴더 접근. EVAL 시뮬레이션은 앱 제어 폴더(임시) 사용으로 권한 마찰 회피.
- 본 Sprint 의 저장은 파일+JSON(Sprint 3 에서 SQLite+FTS5 로 교체).
