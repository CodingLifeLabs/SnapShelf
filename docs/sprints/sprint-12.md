# Sprint 12: 로컬 사용 통계 (셀프 리포트 PMF 지표)

## 구현 범위

PMF 검증 지표를 텔레메트리 없이 로컬에서만 수집·표시한다. PrivacyLog(JSON-lines actor)
패턴을 재사용하고, Settings → Privacy 탭에 "Your usage (local only)" 섹션을 추가한다.

### 파일 목록

**Types**
- `src/Types/UsageStats.swift` — `UsageEventKind` enum(captured/searched/searchHit/copied/pinned/stowed) + `UsageEvent` struct(id/timestamp/kind). Codable·Sendable

**Runtime**
- `src/Runtime/UsageStatsLog.swift` — actor. PrivacyLog 구조 복제: JSON-lines 파일, maxEvents 캡(2000), `record(_:)` / `events() -> [UsageEvent]` / `clear()`

**Service**
- `src/Service/UsageStatsSummary.swift` — 순수 함수 집계: `totalCaptured`, `totalSearches`, `searchHitRate`(searchHit/searched), `totalCopied`, `activeDays`(고유 날짜 수), `eventsLast(days:)` 필터. 밀리초 단위 로직 없음 — Date만 사용

**Runtime (이벤트 훅 — ShelfModel 최소 침투)**
- `ShelfModel.ingest(url:)` 성공 시 `.captured` 1회
- `ShelfModel.runSearch(_:)` — 쿼리 실행 시 `.searched`, 결과 ≥1 시 `.searchHit`
- `ShelfModel.togglePin(id:)` 핀 활성 시 `.pinned`
- `ShelfModel.stow(id:)` `.stowed`
- `App/Sources/Shelf/ShelfView.swift` `onCopyImage` 성공 시 `.copied` (ShelfModel 경유 또는 주입)

**UI**
- `App/Sources/Settings/SettingsView.swift` PrivacySettingsTab 하단: "Your usage (local only)" Section — 총 캡처/검색/검색 명중률/복사/활성 일수 + "This never leaves your Mac" 고지 + Reset 버튼
- `App/Sources/Settings/SettingsModel.swift` — `usageSummary` 로드 (비동기, 뷰 등장 시)

**Tests**
- `Tests/TypesTests/UsageStatsTests.swift` — Codable 왕복, enum 전 케이스
- `Tests/RuntimeTests/UsageStatsLogTests.swift` — record/persist/load/clear/maxEvents 캡 (PrivacyLogTests 패턴)
- `Tests/ServiceTests/UsageStatsSummaryTests.swift` — 집계 정확성, hitRate 0분모, activeDays, last(days:) 필터

## Sprint Contract (GENERATOR ↔ EVALUATOR 합의)

### GENERATOR가 완료해야 할 것 (코드 구현 + 자가 검증)

- [ ] `src/Types/UsageStats.swift`: UsageEventKind + UsageEvent
- [ ] `src/Runtime/UsageStatsLog.swift`: actor (PrivacyLog 패턴, maxEvents 2000)
- [ ] `src/Service/UsageStatsSummary.swift`: 순수 집계 함수
- [ ] ShelfModel 이벤트 훅 (ingest/runSearch/togglePin/stow) — 기존 동작 변경 없음
- [ ] ShelfView 복사 훅
- [ ] PrivacySettingsTab "Your usage" 섹션 + Reset
- [ ] SettingsModel usageSummary 로드
- [ ] 단위 테스트 3파일 (각 계층)
- [ ] Gate 1 통과: `npm run harness:lint` (위반 0건)
- [ ] Gate 2 통과: `xcodebuild build` (오류 0건)
- [ ] Gate 3 통과: `swiftlint lint --strict` (violation 0건)
- [ ] Gate 4 통과: `xcodebuild test -enableCodeCoverage YES` (기존 194 + 신규 전부 통과, 커버리지 ≥80% 유지)
- [ ] Gate 5 통과: `npm run gen:project` 후 빌드 재확인 (신규 파일 반영)
- [ ] `docs/quality.md` 커버리지 수치 갱신

### EVALUATOR가 검증할 것 (사용자 관점 동작)

- [ ] 앱 실행 → Settings → Privacy 탭 → "Your usage (local only)" 섹션 렌더링
- [ ] 지표 카드: Captured / Searches / Search hit rate / Copied / Active days 표시 (빈 상태 = 0 / "—")
- [ ] "This never leaves your Mac" 고지 문구 존재
- [ ] Reset 버튼 클릭 → 지표 0으로 초기화
- [ ] 실제 플로우: 스크린샷 캡처(또는 시뮬레이트) → 캡처 수 +1 확인; 검색 실행 → 검색 수 +1, 결과 있으면 명중률 변화
- [ ] index.sqlite 아닌 usage-stats.jsonl 파일 존재 확인 (Application Support)
- [ ] 통과 기준: 위 전체 정상 작동 + 기존 기능(Shelf/검색/설정) 회귀 없음

## 의존 Sprint
이전 Sprint: 11 (실제 폴더 감시 — ShelfModel.watchers 구조 활용)

## ADR
`docs/design/adr-0012-local-usage-stats.md` — 로컬 전용 통계, 텔레메트리 영구 제외, PrivacyLog 패턴 재사용 결정

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-19 11:36 (KST)

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 59) |
| 2 | 빌드 | ✅ PASS | xcodebuild Debug 오류 0건 |
| 3 | SwiftLint --strict | ✅ PASS | violation 0건 (94 파일) |
| 4 | 테스트 커버리지 | ✅ PASS | 213/213 통과 · Config 86.0 / Repo 92.3 / Runtime 87.0 / Service 86.0 / Types 98.4 |
| 5 | gen:project + 빌드 재확인 | ✅ PASS | 신규 파일 7종 반영 확인 |

### 구현 파일 (커밋 기준)
- `src/Types/UsageStats.swift` — UsageEventKind(6종) + UsageEvent
- `src/Config/AppPaths.swift` — `usageStatsFile` 경로 추가 (`usage-stats.jsonl`)
- `src/Runtime/UsageStatsLog.swift` — actor, JSON-lines, maxEvents 2000
- `src/Runtime/ShelfModel.swift` — ingest/togglePin/stow/runSearch 훅 + `recordUsage(_:)` (주입식, nil=비활성)
- `src/Service/UsageStatsSummary.swift` — 순수 집계 + `eventsLast(days:)`
- `App/Sources/Shelf/ShelfView.swift` — onCopyImage 성공 시 `.copied`
- `App/Sources/Settings/SettingsModel.swift` — `usageSummary` 로드/리셋
- `App/Sources/Settings/SettingsView.swift` — Privacy 탭 "Your usage (local only)" 섹션
- `App/Sources/SnapShelfApp.swift` — UsageStatsLog 생성·주입
- Tests 3파일 신규 (4+7+8=19개) + 기존 AppPaths 테스트 3곳 시그니처 갱신

## EVALUATOR 결과 (2026-08-20)

**PASS** — 전 검증 항목 통과. 상세: `sprint-12-eval.md`

- Privacy 탭 섹션/지표/고지/Reset 렌더링 확인 (창 캡처)
- 라이브 플로우: 캡처→`captured`, 검색→`searched`/`searchHit`(FTS 명중 시) 기록 확인
- UI 수치 ↔ jsonl 실집계 완전 일치 (15/23/4%/2일)
- Reset → 파일 삭제 + UI 0 초기화 + 이후 이벤트 재기록(파일 재생성) 확인
- 스프린트 외 발견 2건 기록: Settings→ShelfModel 설정 미전달, 인앱 OCR 무실패 (quality.md 기술부채)
