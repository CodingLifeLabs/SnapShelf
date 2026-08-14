# SnapShelf — Search Engine

> 2단계: (1) SQLite **FTS5** 키워드 검색(오프라인, 빠름) + (2) AI 의미 검색(옵트인).

## 1. 아키텍처

```
SearchService
├─ KeywordSearcher   (FTS5, 항상 사용 가능)
└─ SemanticSearcher  (AI provider, 옵트인)
       └─ 임베딩 캐시를 둘 수 있으나 v1 은 LLM 에 쿼리+후보 메타 전달 방식
```

## 2. FTS5 키워드 검색 (P0)

- 토크나이저: `porter unicode61 remove_diacritics 2` (한글/영문/분음 부호).
- 색인 대상: `ocrText + displayName + appName + tags`(DATABASE.md).
- 질의: 사용자 입력 → FTS5 쿼리 문법 이스케이프 + AND.
- 랭킹: `bm25(shelf_items_fts)`(기본) + `captured_at` 최근성 가중(선택).
- 결과: 썸네일 + `snippet()` 하이라이트 + 메타. `LIMIT 50`.

```sql
SELECT s.id, s.display_name, s.app_name, s.captured_at,
       snippet(shelf_items_fts,1,'<mark>','</mark>','…',12) AS excerpt,
       bm25(shelf_items_fts) rank
FROM shelf_items_fts f JOIN shelf_items s ON s.id=f.item_id
WHERE shelf_items_fts MATCH :q AND s.is_deleted=0
ORDER BY rank LIMIT 50;
```

## 3. AI 의미 검색 (P1, 옵트인)

- 시나리오: "지난달 ChatGPT 에서 본 API" 같은 자연어.
- v1 접근(임베딩 DB 없이):
  1. LLM 이 자연어 쿼리 → (키워드/앱/기간/주제) 구조화 필터 추출.
  2. 추출 필터로 FTS5 + 메타 필터 후보 축소.
  3. (선택) 후보의 OCR/요약으로 LLM 재랭킹 → 상위 N.
- v2(선택): 임베딩 로컬 저장(sqlite-vec / onnx) → 벡터 검색. ADR 로 결정.

## 4. 검색 UX

- 디바운스 200ms → 스켈레톤 → 결과.
- 결과 순서: 랭크 우선, 최근성 토글.
- 하이라이트: `<mark>` → accent 배경.
- 빈 결과: "결과 없음" + AI 검색 제안(옵트인) / 철자 제안.

## 5. 성능

- FTS5: 100K 장 ≤150ms(WAL + 인덱스 + LIMIT).
- AI 검색: 후보를 ≤200으로 축소 후 LLM 호출(비용/지연 제어).
- 최근 검색어 캐시(로컬, 사용자 삭제 가능).

## 6. 색인 갱신

- 캡처/이동/삭제 시 즉시 FTS5 동기(트랜잭션).
- 재색인(설정): 전체 재구축 + 진행률 + 취소.
- OCR 미완료 항목은 메타(파일명/앱)만 색인 → OCR 완료 시 보강.

## 7. 프라이버시

- FTS5: 전 로컬.
- AI 검색: 옵트인 provider 만. 후보 메타/스니펫 전송, 이미지 자체는 v1 미전송(필요 시 명시).
