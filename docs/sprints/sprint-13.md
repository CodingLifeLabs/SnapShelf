# Sprint 13: 설정 전파 + 인테이크 안정화

## 구현 범위

Sprint 12 EVAL에서 발견한 결함 2건을 수정한다 (ADR-0013).

1. **Settings → ShelfModel 설정 전파**: General 탭의 shelf 설정(auto-stow/hoverSeconds)이
   실제 동작에 반영되게 한다.
2. **인테이크 레이스 방어**: dotfile 임시 파일 무시 + 파일 안정화 대기 + OCR 실패 가시화로
   `ocr_text` 0인 죽은 행/중복 행 발생을 제거한다.

### 파일 목록

**Runtime — DirectoryWatcher (dotfile 방어)**
- `src/Runtime/DirectoryWatcher.swift` — `filteredNames`에서 점두(`.` prefix) 파일 제외

**Runtime — ShelfModel (설정 전파)**
- `src/Runtime/ShelfModel.swift` — `settings`를 `private(set) var`로 변경,
  `applyShelfSettings(_:)` 공개 메서드 추가: 설정 갱신 + resting 항목 stow 재스케줄
  (autoStow=false면 전체 취소)
- `App/Sources/SnapShelfApp.swift` — `settingsModel.onShelfSettingsChanged` 콜백 연결
  (기존 `onFoldersChanged` 옆)

**Service — IntakePipeline (settle + OCR 가시화)**
- `src/Service/IntakePipeline.swift` —
  - `settle(url:)` 정적 헬퍼: 크기 불변 확인(0.35s × 최대 4회), `@Sendable` clock/sleep 주입 가능
  - ingest 시작 전 settle 대기
  - OCR `try?` → 명시적 catch: 실패 시 `ocrStatus = .failed` 기록(기존 `.ok`/nil 유지),
    행은 저장(캡처 손실 금지 원칙 유지)
- `src/Types/ShelfItem.swift` — `ocrStatus: OCROStatus?` 필드 추가 (`.ok`/`.failed`, Codable 기본 nil)

**Tests**
- `tests/RuntimeTests/DirectoryWatcherTests.swift` — dotfile 제외 케이스 추가
- `tests/RuntimeTests/ShelfModelSettingsTests.swift` (신규) — applyShelfSettings 갱신/재스케줄/취소
- `tests/ServiceTests/IntakePipelineTests.swift` — OCR 실패 시 failed 마킹 + 행 저장, settle 순수 로직

## Sprint Contract (GENERATOR ↔ EVALUATOR 합의)

### GENERATOR가 완료해야 할 것 (코드 구현 + 자가 검증)

- [ ] DirectoryWatcher dotfile 제외 + 테스트
- [ ] ShelfModel.applyShelfSettings + settings var화 + 테스트
- [ ] SnapShelfApp onShelfSettingsChanged 연결
- [ ] IntakePipeline settle + OCR 실패 가시화 + 테스트
- [ ] ShelfItem.ocrStatus 필더 + Codable 하위호환(기존 DB 행 nil) 테스트
- [ ] Gate 1 통과: `npm run harness:lint` (위반 0건)
- [ ] Gate 2 통과: `xcodebuild build` (오류 0건)
- [ ] Gate 3 통과: `swiftlint lint --strict` (violation 0건)
- [ ] Gate 4 통과: `xcodebuild test -enableCodeCoverage YES` (기존 213 + 신규 전부 통과, 커버리지 ≥80%)
- [ ] Gate 5 통과: `npm run gen:project` 후 빌드 재확인 (신규 파일 있으면)
- [ ] `docs/quality.md` 커버리지 수치 갱신

### EVALUATOR가 검증할 것 (사용자 관점 동작)

- [ ] General 탭 "Auto-stow after hover time" 끄기 → 새 캡처가 5초 뒤에도 resting 유지 (S12 EVAL 재현 시나리오)
- [ ] 다시 켜기 → 신규 항목만 auto-stow (기존 resting 항목 소급 stow 안 함 — 재스케줄 정책 확인)
- [ ] hoverSeconds 변경(예: 5→15) 반영 확인
- [ ] 실제 스크린샷(`screencapture` → Desktop) 캡처 → DB에 **행 1건만** 등록 (dotfile 중복 행 없음)
- [ ] 캡처 후 ocr_text ≥ 1 (완성된 파일에 대해 OCR 성공)
- [ ] OCR 실패 시나리오(손상 PNG) → 행 존재 + ocrStatus=failed (침묵 아님)
- [ ] 기존 기능 회귀 없음: Shelf/검색/설정/Library/사용 통계

## 의존 Sprint
이전 Sprint: 12 (로컬 사용 통계 — EVAL에서 본 결함 발견)

## ADR
`docs/design/adr-0013-intake-stability-and-settings-propagation.md`

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-20 23:08 KST

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 (`harness:lint`) | ✅ PASS | 위반 0건 (파일 59개) |
| 2 | 빌드 (`xcodebuild build`) | ✅ PASS | 오류 0건 |
| 3 | SwiftLint (`--strict`) | ✅ PASS | violation 0건 (95 파일) |
| 4 | 테스트 + 커버리지 | ✅ PASS | 224 tests 전부 통과 (기존 213 + 신규 11). 커버리지: Config 89.47% / Repo 89.98% / Runtime 87.29% / Service 86.54% / Types 98.39% |
| 5 | `gen:project` + 재빌드 | ✅ PASS | 프로젝트 동기화 후 BUILD SUCCEEDED |

### 구현 중 발견·수정된 추가 결함

**프로덕션 버그 — settle 크기 프로브의 캐시된 stat**:
`URL.resourceValues(forKeys: [.fileSizeKey])`는 URL 객체에 캐시된 크기를 반환한다.
settle 프로브가 이 API를 쓰면 첫 프로브에서 캐시된 동일 값과 비교해 "안정"으로 오판정할 수 있었다.
`FileManager.attributesOfItem(atPath:)`(fresh stat)로 교체했다. 테스트가 이 버그를 잡았다
(주입된 sleep이 파일을 성장시켜도 프로브 크기가 계속 같게 관측됨).

**테스트 안정화 — settle 대기 테스트 재작성**:
외부 writer Task와 프로브 간 실시간 레이스로 플래키했다. sleep 클로저 자체가 파일을
성장시키는 구조로 재작성해 결정론적으로 만들었다 (probed 4/4회, 크기 단조 증가 검증).
