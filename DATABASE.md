# SnapShelf — Database Design

> SQLite + FTS5(시스템 sqlite 포함). Repo 레이어가 단독 소유.
> 위치: `~/Library/Application Support/SnapShelf/index.sqlite`

## 1. 스키마

```sql
-- 메타데이터(정규화)
CREATE TABLE IF NOT EXISTS shelf_items (
    id            TEXT PRIMARY KEY,            -- UUID
    source_url    TEXT NOT NULL,               -- 원본 파일 경로(이동 시 갱신)
    display_name  TEXT NOT NULL,
    original_name TEXT,                         -- 캡처 시 원본 파일명
    captured_at   INTEGER NOT NULL,             -- epoch ms
    ingested_at   INTEGER NOT NULL,
    app_name      TEXT,
    window_title  TEXT,
    browser_url   TEXT,
    category      TEXT,                         -- ItemCategory raw
    collection_id TEXT,
    is_pinned     INTEGER NOT NULL DEFAULT 0,
    is_deleted    INTEGER NOT NULL DEFAULT 0,
    deleted_at    INTEGER,
    width         INTEGER,
    height        INTEGER,
    file_size     INTEGER,
    phash         TEXT,                         -- 중복 탐지용 지각 해시
    summary       TEXT,
    tags_json     TEXT                          -- [String] JSON
);

CREATE INDEX IF NOT EXISTS idx_items_captured ON shelf_items(captured_at DESC);
CREATE INDEX IF NOT EXISTS idx_items_app      ON shelf_items(app_name);
CREATE INDEX IF NOT EXISTS idx_items_category ON shelf_items(category);
CREATE INDEX IF NOT EXISTS idx_items_collection ON shelf_items(collection_id);

-- FTS5 전문검색(OCR 텍스트 + 파일명 + 앱 + 태그)
CREATE VIRTUAL TABLE IF NOT EXISTS shelf_items_fts USING fts5(
    item_id UNINDEXED,
    content,
    tokenize = 'porter unicode61 remove_diacritics 2'
);

-- Smart Folder 규칙
CREATE TABLE IF NOT EXISTS folder_rules (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    kind       TEXT NOT NULL,                   -- app|domain|project|regex|category
    pattern    TEXT NOT NULL,
    target_dir TEXT NOT NULL,
    priority   INTEGER NOT NULL DEFAULT 0,
    enabled    INTEGER NOT NULL DEFAULT 1
);

-- 컬렉션
CREATE TABLE IF NOT EXISTS collections (
    id         TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    kind       TEXT NOT NULL                    -- manual|ai
);

-- 스키마 버전(마이그레이션)
CREATE TABLE IF NOT EXISTS schema_meta (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

## 2. 색인 흐름

```
새 항목 insert(shelf_items)
  → OCR 완료 시 INSERT INTO shelf_items_fts(item_id, content)
    content = ocrText + " " + displayName + " " + appName + " " + tags.join(" ")
  → 파일 이동(Repo) 시 source_url 갱신(FTS 는 item_id 기준이라 영향 없음)
```

## 3. 마이그레이션

- `schema_meta.version` 으로 버전 관리.
- 시작 시 버전 비교 → 순차 마이그레이션(트랜잭션). 실패 시 원본 백업 후 중단(원본 보존).
- FTS5 스키마 변경은 shadow 테이블 재생성 파이프라인(재색인).

## 4. 동시성·무결성

- WAL 모드(`PRAGMA journal_mode=WAL`) → 읽기/쓰기 동시.
- 쓰기는 직렬 큐(actor). 읽기는 자유.
- 트랜잭션 단위로 원자성 보장(특히 파일 이동 + 메타 갱신).
- 무결성: 파일 이동 실패 시 DB 롤백(메타와 파일위치 불일치 방지).

## 5. 검색 쿼리 예시

```sql
-- 키워드 검색(스니펫 + 랭크)
SELECT s.id, s.display_name, s.app_name, s.captured_at,
       snippet(shelf_items_fts, 1, '<mark>', '</mark>', '…', 12) AS excerpt,
       bm25(shelf_items_fts) AS rank
FROM shelf_items_fts f
JOIN shelf_items s ON s.id = f.item_id
WHERE shelf_items_fts MATCH :query AND s.is_deleted = 0
ORDER BY rank
LIMIT 50;
```

## 6. 용량·성능

- 100K 항목 기준: FTS5 인덱스 ~ 수백 MB(OCR 텍스트량에 따라).
- 검색 ≤150ms 타깃 → `LIMIT 50` + 인덱스 + WAL.
- 썸네일/이미지는 DB 에 저장하지 않음(파일 시스템). 메타만.

## 7. 백업·초기화

- DB 는 사용자 데이터 폴더. "모든 데이터 초기화" = DB 삭제 + 이미지 폴더 옵션(2단계 확인).
- 내보내기: JSON(메타 + 경로) — 설정에서.
