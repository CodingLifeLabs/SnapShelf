# SnapShelf 품질 현황

> Harness 게이트 통과 결과와 기술 부채를 한 곳에서 추적한다.

## 현재 등급

- **상태**: 🟢 Sprint 11 완료 (실제 스크린샷 폴더 감시, ADR-0011) — EVAL PASS. v0.1.1 출시 완료 (2026-08-18)
- **커버리지**: Config 85.8 · Repo 92.3 · Runtime 86.5 · Service 85.6 · Types 98.2 (전 ≥80% ✅)
- **레이어 위반**: 0건 (Gate 1)
- **빌드**: 성공 — Debug + Release (ad-hoc, Hardened Runtime)
- **테스트**: 194/194 통과
- **배포**: GitHub Release v0.1.1 (SnapShelf-0.1.1.dmg 2.2MB + SHA-256) · Pages 랜딩(상대경로 수정+enhance.js 재작성 반영)
- **비고**: 다음 신규 기능은 신규 PLANNER 사이클부터

## 5개 게이트 (네이티브 Swift 적응)

| Gate | 항목 | 명령 | 통과 기준 |
|------|------|------|-----------|
| 1 | 레이어 의존성 | `npm run harness:lint` | 위반 0건 |
| 2 | 타입/컴파일 | `xcodebuild -scheme SnapShelf build` | 오류 0건 |
| 3 | 코드 품질 | `swiftlint lint --strict` | error 0건 |
| 4 | 테스트 커버리지 | `xcodebuild test ... -enableCodeCoverage YES` | line ≥ 80%, 실패 0 |
| 5 | 빌드 성공 | `xcodebuild -scheme SnapShelf build` | 성공 |

> EVALUATOR는 빌드 + `open` 실행 + `screencapture` (또는 XCUITest) 로 사용자 관점 동작 검증.

## 기술 부채 / TODO

- ~~(Sprint 3) GRDB.swift 도입 여부~~ → ADR-0008 시스템 SQLite3 유지 확정
- ~~(Sprint 4) Foundation Models 가용성 게이트~~ → macOS 26 `#available` 게이트 구현. 본 기기 Intel/macOS 15 → 클라우드/Ollama fallback 기본 (ADR-0006)
- ~~(Sprint 9) 랜딩 페이지~~ → `web/` + Pages 배포 완료
- (보류) ADR-0009 임베딩 벡터 검색 — v2 검토
- (게이트 대기) Apple 공증 — Developer ID 인증서 확보 시 ADR-0010 4단계 절차 (사용자 확인 필수)
- ~~(대화형 환경) Shelf 패널·애니메이션 체감 확인~~ → 2026-08-18 대화형 EVAL 완료: `docs/sprints/interactive-eval-2026-08-18.md` — 조건부 PASS. **P0-2 실제 스크린샷 폴더(Desktop 등) 미감시가 CRITICAL로 확인됨**(⌘⇧4 캡처가 앱에 반영 안 됨) + enhance.js DMG 재작성 데드코드 + 패널 배치(포커스 스크린·4px 클리핑). v0.1.1 최우선 후보.
- (대기) XCUITest 도입 여부 — 이번 EVAL은 osascript+screencapture로 대체 수행

## 테스트 전략 (macOS 네이티브)

1. **단위(Unit)**: XCTest, 순수 로직(Types/Service/Repo) — 통합 번들 `SnapShelfTests`
2. **통합**: Repo ↔ FTS5 인덱싱, OCR 파이프라인(샘플 이미지)
3. **E2E/동작**: 빌드 후 `open` → `screencapture` + (선택) XCUITest
4. **시각회귀**: Shelf 패널·애니메이션 상태 캡처 비교(수동/스크립트)
