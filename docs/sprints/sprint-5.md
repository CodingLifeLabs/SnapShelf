# Sprint 5: Smart Folder 자동 정리

## 구현 범위
- 출처 감지: 활성 창 메타데이터(CGWindowListCopyWindowInfo)/AppleScript(브라우저 URL) + 파일명 휴리스틱
- `FolderRule` 엔진: kind(app|domain|project|regex|category), 우선순위, enabled
- `Organizer`: 규칙 매칭 → 대상 디렉토리 생성 + 파일 이동(원자적, 원본 보존, 실행취소)
- 디렉토리 구조: `Screenshots/{yyyy}/{mm}/{App}/` 또는 `Screenshots/{App}/`(사용자 선택)
- Library 사이드바 실시간 반영(폴더 트리 + 카운트)
- AI 규칙 제안(옵트인): 자주 나타나는 주제로 규칙 후보

### 파일(예상)
- `src/Service/Organizer.swift`, `SourceDetector.swift`, `FolderRuleEngine.swift`
- `src/Repo/FolderRuleRepository.swift`
- `App/Sources/Library/FolderSidebar.swift`

## GENERATOR가 완료해야 할 것
- [ ] 규칙 매칭/이동/실행취소 단위 테스트(임시 디렉토리 fixture)
- [ ] 원본 보존: 이동 실패 시 원상복구 테스트
- [ ] Gate 1~5 통과

## EVALUATOR가 검증할 것
- [ ] 시뮬레이션 캡처(앱 메타 부여) → 자동 폴더 이동 → Library 사이드바 반영
- [ ] 잘못된 이동 시 실행취소/원상복구 동작
- [ ] 통과 기준: "캡처가 자동으로 올바른 폴더로 정리됨"

## 의존 Sprint
이전: Sprint 3 (필수), Sprint 4 (AI 규칙 제안용, 권장)

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-14

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 29) |
| 2 | 빌드/컴파일 | ✅ PASS | 오류 0건 |
| 3 | SwiftLint(--strict) | ✅ PASS | error 0건 (135파일) |
| 4 | 테스트 커버리지 | ✅ PASS | 99/99 통과, 전체 87.2% (Config 92 · Repo 92 · Runtime 89 · Service 81 · Types 97) |
| 5 | 빌드 성공 | ✅ PASS | 경고 0건 |

> 범위 조정: TCC 안전 경로(앱 제어 Library 폴더 내 정리)로 구현/검증.
> 사용자 폴더(~/Pictures 등) 연동·접근성 기반 감지는 설정/권장 업그레이드로 연기.

