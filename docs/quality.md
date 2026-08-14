# SnapShelf 품질 현황

> Harness 게이트 통과 결과와 기술 부채를 한 곳에서 추적한다.

## 현재 등급

- **상태**: 🟢 Sprint 2 완료 (EVAL PASS) / Sprint 3 대기
- **커버리지**: 95.0% line (목표 ≥80% ✅) — Config 90 · Repo 98 · Runtime 94 · Service 97 · Types 100
- **레이어 위반**: 0건 (Gate 1)
- **빌드**: 성공 (경고 0)
- **테스트**: 42/42 통과
- **비고**: Sprint 2 UI 인터랙션(드래그/공유/호버) 시각 검증은 대화형 환경 보완 예정

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

- (Sprint 3 예정) GRDB.swift 도입 여부 결정 — 시스템 `SQLite3` vs GRDB
- (Sprint 4 예정) Foundation Models 가용성 게이트(macOS 26+). 본 기기는 macOS 15 / Intel → 온디바이스 LLM은 클라우드/Ollama fallback
- (Sprint 9 예정) 랜딩 페이지 별도 웹 프로젝트(web/)
- Apple 코드사이닝/공증(provisioning) — 배포 시점에 사용자 확인 필요

## 테스트 전략 (macOS 네이티브)

1. **단위(Unit)**: XCTest, 순수 로직(Types/Service/Repo) — 통합 번들 `SnapShelfTests`
2. **통합**: Repo ↔ FTS5 인덱싱, OCR 파이프라인(샘플 이미지)
3. **E2E/동작**: 빌드 후 `open` → `screencapture` + (선택) XCUITest
4. **시각회귀**: Shelf 패널·애니메이션 상태 캡처 비교(수동/스크립트)
