# Sprint 11: 진짜 캡처 — 실제 스크린샷 폴더 감시 (v0.1.1)

> 사용자 요구: "simulate capture 가 아니라 진짜 capture를 해야 이 프로그램이 쓸모가 있어."
> ADR-0011 채택. 2026-08-18 대화형 EVAL CRITICAL(P0-2 미구현) 해소.

## 구현 범위

### 1. Config 레이어
- `src/Config/ScreenshotFolders.swift` (신규)
  - `ScreenshotFolderSource` 프로토콜 + `DefaultScreenshotFolderSource`
  - 감지 순서: `com.apple.screencapture location` → `~/Desktop` →
    `~/Pictures/Screenshots`(존재 시) → Inbox(항상) + 사용자 추가 폴더
  - `resolve(home:defaults:fileExists:userFolders:)` 순수 함수 — 테스트 가능
- `AppSettings`에 `watchedFolders: [String]`(사용자 추가 경로, 기본 `[]`)

### 2. Runtime 레이어
- `ShelfModel.startWatcher()` → 다중 폴더:
  - 각 폴더마다 `DirectoryWatcher` 인스턴스
  - `bootstrap()`에서 폴더별 감시 시작, 개별 실패는 상태 메시지에 반영
  - `watchedFolderStates: [FolderWatchState]`(path, isDenied) 공개 — Settings UI용
- 기존 파일 시딩 로직 유지(과거 파일 색인 없음)

### 3. App(UI) 레이어
- `ShelfPanelController.show()`: `NSScreen.main` → **상태바 아이콘이 있는 화면** 기준
  + `panelSize` 460 → 488(SwiftUI 실측) 수정
- `CaptureSettingsTab`: 감시 폴더 목록 표시 + 상태(✅/🚫) + "Add Folder"(NSOpenPanel) +
  제거 버튼. Inbox/Library/Recordings 경로는 추가 거부
- 상태바 statusMessage에 감시 폴더 수 표시

### 4. 웹(1줄)
- `web/assets/enhance.js`: 데드코드 셀렉터 수정 — `a[href="#download"]` 재작성 대상에
  `releases/latest` href의 `btn-lg` 포함

## Sprint Contract (GENERATOR ↔ EVALUATOR 합의)

### GENERATOR가 완료해야 할 것
- [ ] `ScreenshotFolders.swift` + 단위 테스트(경로 해석·중복 제거·보호 경로 거부)
- [ ] `ShelfModel` 다중 워처 + 테스트(폴더별 독립 감시·denied 처리)
- [ ] `AppSettings.watchedFolders` 영속화 + 테스트
- [ ] `ShelfPanelController` 위치·크기 수정
- [ ] `CaptureSettingsTab` 폴더 목록 UI + 추가/제거
- [ ] `enhance.js` 셀렉터 수정
- [ ] Gate 1: `npm run harness:lint` 위반 0건
- [ ] Gate 2: `xcodebuild build` 오류 0건
- [ ] Gate 3: `swiftlint lint --strict` error 0건
- [ ] Gate 4: `xcodebuild test -enableCodeCoverage YES` — line ≥80%, 실패 0
- [ ] Gate 5: 빌드 성공
- [ ] CHANGELOG.md 업데이트

### EVALUATOR가 검증할 것 (사용자 관점)
- [ ] 앱 실행 → `~/Desktop`에 실제 파일 복제 → Shelf 등장 (진짜 캡처 시나리오)
- [ ] 실제 `screencapture` CLI로 캡처 → Desktop에 파일 낙하 → Shelf 등장
- [ ] TCC 거부 시나리오: denied 폴더 표시 + 나머지 감시 유지 (단위 테스트로 대체 검증)
- [ ] Shelf 패널: 메인 디스플레이 우하단 배치, 4px 클리핑 없음
- [ ] Settings → Capture & Folders: 폴더 목록·상태·추가/제거 동작
- [ ] 랜딩 enhance.js: DMG 버튼이 직접 다운로드 링크로 재작성됨 (로컬 정적 서빙 검증)

## 의존 Sprint
이전: Sprint 10 (완료). 본 스프린트는 독립 수행 가능.

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-18 13:12 (KST)

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 (`npm run harness:lint`) | ✅ PASS | 위반 0건 (파일 56) |
| 2 | 빌드 (`xcodebuild build`) | ✅ PASS | BUILD SUCCEEDED (AppIntents 메타데이터 경고는 무관) |
| 3 | SwiftLint `--strict` | ✅ PASS | error 0건 |
| 4 | 테스트+커버리지 | ✅ PASS | 194/194 통과 (신규 17). Config 85.8 · Repo 92.3 · Runtime 86.5 · Service 85.6 · Types 98.2 (전 ≥80%) |
| 5 | 빌드 성공 | ✅ PASS | Debug 구성 |

커밋: `feat: Sprint 11 — real screenshot folder watching (ADR-0011)`

## 비고

- 범위 외(out): ScreenCaptureKit 직접 캡처 기능(ADR-0003 유지), 창/영역 캡처 UI,
  iCloud 스크린샷 싱크 대응.
- 릴리스: 본 스프린트 PASS 시 v0.1.1 태그+DMG(ADR-0010 절차, ad-hoc+Hardened Runtime).
