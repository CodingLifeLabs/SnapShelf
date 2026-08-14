# SnapShelf — TASKS (Claude Code 작업 순서)

> PLANNER 핸드오프. 위→아래 순서로 GENERATOR/EVALUATOR 사이클 실행.
> 각 Sprint 마다 5 Gate 통과 후 EVALUATOR 검증 → PASS 시 다음.

## Sprint 1 — Foundation (실행 우선순위 최상)

1. `npm run gen:project` 로 프로젝트 동기화(새 파일마다)
2. `src/Types`: ShelfItem, ItemCategory, 관련 값타입 + 테스트
3. `src/Config`: AppPaths, ShelfSettings + 테스트
4. `src/Repo`: 파일+JSON 저장소(InMemoryShelfRepository/FileShelfRepository 프로토콜 기반) + 테스트
5. `src/Service`: (Sprint1은 최소) IntakePipeline 스켈레톤 + 테스트
6. `src/Runtime`: StatusBarCoordinator, ScreenshotWatcher(FSEvents), ShelfPanelController + 테스트
7. `App/Sources`: SwiftUI App 진입, ShelfView, ShelfItemView, 시뮬레이션 캡처 액션
8. Gate 1~5 통과 → 커밋 → EVALUATOR(빌드+open+screencapture)

## Sprint 2 — Shelf 인터랙션
- NSItemProvider 드래그 / 복사 / 공유 / 핀 / 호버 툴바 / 소멸 타이머 / 히스토리 토글
- Gate 1~5 → EVAL(각 액션 동작)

## Sprint 3 — 저장소+OCR+검색
- SQLiteShelfRepository(GRDB 또는 시스템 SQLite3) + FTS5 / VisionOCRService / KeywordSearcher
- Gate 1~5 → EVAL(검색 결과 하이라이트)

## Sprint 4 — AI provider
- AIService 프로토콜 + 구현체(FoundationModels/HTTP/Ollama) + 팩토리 + 옵트인/Keychain
- 이름변경/요약 + 테스트(규칙 폴백 포함)
- Gate 1~5 → EVAL(옵트인 후 이름변경)

## Sprint 5 — Smart Folder
- FolderRule 엔진 + Organizer + 앱/도메인 감지 + 자동 이동(원본보존/실행취소)
- Gate 1~5 → EVAL(자동 정리 + Library 반영)

## Sprint 6 — 검색/타임라인/컬렉션
- LibraryWindow + TimelineView + Collections + AI 의미검색
- Gate 1~5 → EVAL(탐색 동작)

## Sprint 7 — 정리/중복/메모/클립보드
- AutoCleanup + Deduplicator(pHash) + Notes + ClipboardHistory
- Gate 1~5 → EVAL(라이프사이클)

## Sprint 8 — 설정/프라이버시/URL/Dev Mode
- SettingsWindow + BrowserURLDetector + DevMode + 녹화 정리
- Gate 1~5 → EVAL(전 설정)

## Sprint 9 — 랜딩+브랜드
- `web/` 정적 사이트 + AppIcon/로고 + 비교페이지 + CWV/접근성
- EVAL(랜딩 시각/성능)

## Sprint 10 — 폴리시/공증
- 애니메이션 튜닝 + 접근성 최종 + Hardened Runtime + 공증/DMG
- EVAL(배포 산출물)

## 횡단(cross-cutting) 작업

- ADR(`docs/design/INDEX.md`): GRDB 도입여부(S3), 임베딩 검색여부(S6/v2), 공증전략(S10)
- 각 Sprint 후 `CHANGELOG.md` / `docs/quality.md` 갱신
- 리스크 게이트(R1~R4, ROADMAP.md) 사전 점검
