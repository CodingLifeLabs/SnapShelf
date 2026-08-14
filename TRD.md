# SnapShelf — Technical Requirements Document (TRD)

> 버전 0.1 · 2026-08-14 · 작성: PLANNER
> 구현 청사진. 아키텍처 상세는 `docs/architecture.md`, 데이터는 `DATABASE.md`,
> AI 는 `AI_ARCHITECTURE.md`, OCR 은 `OCR_ENGINE.md`, 검색은 `SEARCH_ENGINE.md`.

## 1. 기술 스택 (확정)

| 영역 | 기술 | 비고 |
|------|------|------|
| 언어/UI | Swift 6.2 / SwiftUI + AppKit | macOS 14.0+ |
| 상태 | `@Observable` (Observation 프레임워크) | Swift 6 동시성(actor/Sendable) |
| 캡처 | ScreenCaptureKit, `CGWindowList` | 주문 캡처 |
| 파일 감시 | `DispatchSource.makeFileSystemObjectSource` / FSEvents | 스크린샷 폴더 |
| OCR | Vision `VNRecognizeTextRequest` | 오프라인, 정밀도 `accurate` |
| 저장 | SQLite3(시스템) + **FTS5** | GRDB.swift 도입 검토(Sprint 3) |
| AI | Foundation Models / OpenAI / Claude / Gemini / Ollama | provider protocol |
| 빌드 | XcodeGen(`Project.yml`) → `SnapShelf.xcodeproj` | static framework 6 모듈 |

## 2. 모듈 책임 (레이어별)

### Types (`SnapShelfTypes`)
순수 값 타입. 프레임워크 의존성 0.
```swift
public struct ShelfItem: Identifiable, Sendable { ... }      // id, url, createdAt, app, urlMeta?, ocrText?, summary?, ...
public enum ItemCategory: Sendable { case chat, code, error, receipt, design, meme, document, terminal, other }
public struct FolderRule: Sendable { ... }                    // 정리 규칙
public protocol ClassifierProtocol: Sendable { ... }          // 역전용(Repo 가 Service 를 모르게)
```

### Config (`SnapShelfConfig`)
경로·상수·설정 스키마. UserDefaults/JSON 코딩.
```swift
public struct AppPaths { /* screenshotsDir, libraryDir, dbPath */ }
public struct ShelfSettings { /* hoverSeconds, historyLimit, cleanupDays */ }
public struct AIProviderConfig { /* provider, model, endpoint?, apiKeyRef */ }
```

### Repo (`SnapShelfRepo`)
영속성/데이터 접근. SQLite + FTS5. 파일 시스템 I/O.
```swift
public protocol ShelfItemRepository: Sendable {
    func insert(_ item: ShelfItem) async throws
    func recent(_ limit: Int) async throws -> [ShelfItem]
    func search(_ query: String) async throws -> [ShelfItem]   // FTS5
    func updateMetadata(...) async throws
}
public final class SQLiteShelfRepository: ShelfItemRepository { ... }
```

### Service (`SnapShelfService`)
비즈니스 로직. 모든 "AI/OCR/정리/이름변경/중복" 유스케이스.
```swift
public protocol OCRService: Sendable { func recognize(_ url: URL) async throws -> String }
public protocol AIService: Sendable { ... }                   // rename/summary/classify/search
public final class IntakePipeline { ... }                     // 캡처→후처리 오케스트레이션
public final class Organizer { ... }                          // Smart Folder 규칙 적용
public final class Deduplicator { ... }                       // pHash 유사도
```

### Runtime (`SnapShelfRuntime`)
앱 라이프사이클. 메뉴바·패널·감시·권한·핫키. AppKit 주도.
```swift
public final class StatusBarCoordinator { ... }               // NSStatusItem
public final class ShelfPanelController { ... }               // NSPanel(.nonactivatingPanel)
public final class ScreenshotWatcher { ... }                  // FSEvents
public final class PermissionManager { ... }                  // TCC 권한 요청/상태
```

### UI (App, `SnapShelf`)
SwiftUI 진입점. Shelf 뷰·라이브러리/검색/타임라인·설정. Runtime 이 노출한 상태를 소비.

## 3. 핵심 데이터 흐름

### 캡처 → Shelf (Sprint 1–2)
```
ScreenshotWatcher (FSEvents, Runtime)
   └─ 새 PNG 감지 → ShelfItem(id,url,createdAt) 생성
        └─ AppState (@Observable) 에 추가
             └─ ShelfPanelController: ShelfItemView 애니메이션 진입(우하단→스택)
                  └─ 5초 후 축소(또는 핀 유지)
```

### 후처리 파이프라인 (Sprint 3–5)
```
IntakePipeline (Service)
  1. OCRService.recognize(url) → ocrText
  2. Repo.search/insert FTS5 색인
  3. (옵트인) AIService.classify → ItemCategory / AIService.rename → 새 파일명
  4. Organizer.apply(ShelfItem, [FolderRule]) → 이동(Repo)
  5. AppState 반영
```

## 4. 동시성 모델

- Swift 6 **strict concurrency**(단계적: Sprint 1 은 `minimal`, 이후 `complete`).
- I/O(OCR·DB·AI·파일이동)는 `async`, 백그라운드 actor.
- UI 는 메인 액터 전용. 상태 전달은 `@Observable` + `Sendable` 값 타입.
- OCR 은 CPU 집중 → 별도 `Task` + 우선순위 `.utility`.

## 5. 저장 설계 (요약)

- 메타데이터 + FTS5 인덱스: `~/Library/Application Support/SnapShelf/index.sqlite`
- 이미지 원본: 사용자가 선택한 라이브러리 폴더(기본 `~/Pictures/SnapShelf`) 또는 Smart Folder 구조.
- 스키마/FTS5 토크나이저/마이그레이션: `DATABASE.md`.

## 6. 프라이버시 & 보안

- **오프라인 기본**: OCR(Vision)·FTS5 는 전 로컬.
- **AI 옵트인**: provider + 키( Keychain 저장, 소스 금지). 클라우드 전송 시 **해당 항목만**, UI 에 표시.
- **Hardened Runtime**(릴리즈). 권한 최소화.
- 시크릿(`.env`/Keychain) 소스 하드코딩 금지(CLAUDE.md 규칙).

## 7. 성능 타깃

| 항목 | 타깃 | 전략 |
|------|------|------|
| Shelf 진입 | ≤200ms | SwiftUI 트랜지션, 사전 썸네일(NSImage by size) |
| 검색(100K장) | ≤150ms | FTS5 인덱스, 결과 페이지네이션 |
| OCR 처리량 | ≥2장/s | 백그라운드 `.utility`, 배치 |
| 상주 메모리 | ≤120MB | 썸네일 캐시 LRU, 느린 로딩 |

## 8. 테스트 전략

- **Unit(XCTest)**: Types/Service/Repo 순수 로직. 통합 번들 `SnapShelfTests`. 커버리지 ≥80%.
- **통합**: FTS5 색인↔검색, OCR 파이프라인(샘플 이미지), Smart Folder 규칙.
- **동작(EVAL)**: 빌드 + `open` + `screencapture` (+ XCUITest).
- **회귀**: Shelf 패널·애니메이션 상태 캡처(SCREEN_STATES.md).

## 9. 빌드·게이트 (harness 적응)

| Gate | 명령 | 기준 |
|------|------|------|
| 1 | `npm run harness:lint` | 레이어 위반 0 |
| 2 | `xcodebuild build` | 컴파일 오류 0 |
| 3 | `swiftlint lint --strict` | error 0 |
| 4 | `xcodebuild test -enableCodeCoverage YES` | line ≥80% |
| 5 | `xcodebuild build` | 성공 |

## 10. 의존성(외부) 정책

- 원칙: 시스템 프레임워크 우선(Vision/ScreenCaptureKit/SQLite3).
- 추가 검토: GRDB.swift(SQLite 래퍼, Sprint 3), 가능한 KeychainAPI 래퍼.
- 각 추가는 ADR(`docs/design/INDEX.md`) 로 기록.
