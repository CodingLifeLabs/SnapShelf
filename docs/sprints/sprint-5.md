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
