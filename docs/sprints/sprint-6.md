# Sprint 6: 검색/타임라인/컬렉션 UI

## 구현 범위
- `LibraryWindow`: 마스터-디테일(사이드바 폴더·컬렉션 + 메인 그리드/리스트)
- `TimelineView`: 시간축(앱 색 점) + 스크럽(SCREEN_STATES.md §4, ANIMATION_SPEC §8)
- `Collections`: 동일 주제 자동 컬렉션(AI, 옵트인) + 수동
- `SemanticSearcher`: AI 의미검색(SEARCH_ENGINE.md §3) — 자연어→필터→FTS5 후보→재랭킹
- 검색 UX: 디바운스/스켈레톤/하이라이트/최근 검색어

### 파일(예상)
- `App/Sources/Library/LibraryWindow.swift`, `TimelineView.swift`, `CollectionsView.swift`, `SearchPane.swift`
- `src/Service/SemanticSearcher.swift`, `CollectionBuilder.swift`

## GENERATOR가 완료해야 할 것
- [ ] 탐색/필터/정렬 단위 테스트
- [ ] 의미검색 목 기반 테스트(실제 LLM 없이)
- [ ] Gate 1~5 통과

## EVALUATOR가 검증할 것
- [ ] 사이드바 폴더 선택 → 해당 항목 표시
- [ ] 타임라인 스크럽 → 그룹 하이라이트
- [ ] 자연어 검색(옵트인) → 의미 일치 결과
- [ ] 통과 기준: "탐색/타임라인/컬렉션이 동작"

## 의존 Sprint
이전: Sprint 5
