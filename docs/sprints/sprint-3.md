# Sprint 3: 저장소 + OCR + 텍스트 검색

## 구현 범위
- `SQLiteShelfRepository`(GRDB.swift 도입 또는 시스템 SQLite3) + FTS5(DATABASE.md)
- 스키마/마이그레이션(WAL, schema_meta 버전)
- `VisionOCRService`(OCR_ENGINE.md): accurate + 다국어(ko/en/ja) + 위→아래 정렬
- IntakePipeline 확장: 캡처 → OCR → FTS5 색인
- `KeywordSearcher`(SEARCH_ENGINE.md §2): bm25 + snippet 하이라이트
- ShelfPanel 검색입력(⌘F) → 결과(스니펫)

### 파일(예상)
- `src/Repo/SQLiteShelfRepository.swift`, `Schema.swift`, `FTSIndex.swift`
- `src/Service/VisionOCRService.swift`, `KeywordSearcher.swift`
- `App/Sources/Shelf/SearchBar.swift`, `SearchResultsView.swift`
- ADR: GRDB vs 시스템 SQLite3(`docs/design/INDEX.md`)

## GENERATOR가 완료해야 할 것
- [ ] Repo 교체(FileShelfRepository → SQLiteShelfRepository, 프로토콜 유지)
- [ ] OCR/검색 단위 + 통합 테스트(샘플 이미지 fixture)
- [ ] Gate 1~5 통과. 100K 장 부하 테스트(선택, 합성 데이터)

## EVALUATOR가 검증할 것
- [ ] 샘플 캡처(텍스트 포함) 후 검색 → 결과에 해당 항목 + 하이라이트
- [ ] 빈 결과 상태 정상
- [ ] 재색인(설정) 동작(초안)
- [ ] 통과 기준: "이미지 내 텍스트로 검색이 동작"

## 의존 Sprint
이전: Sprint 2
