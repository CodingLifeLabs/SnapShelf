# SnapShelf — Roadmap

> 10 Sprint. 각 Sprint = GENERATOR(구현+5Gate) → EVALUATOR(빌드/실행/검증) 사이클.
> 마일스톤은 PRD.md §7 참조. Sprint 상세는 `docs/sprints/sprint-N.md`.

## Sprint 1 — Foundation & Capture→Shelf
- 6 모듈 static framework + 앱 타깃 빌드, 메뉴바 상주, 스크린샷 폴더 감시(FSEvents),
  Shelf 패널 + 항목 등장 애니메이션, 파일+JSON 저장, "시뮬레이션 캡처" 액션.
- **DoD**: ⌘⇧4(또는 시뮬) → Shelf 에 항목 등장. 앱 빌드/실행/스크린샷 검증.

## Sprint 2 — Shelf 인터랙션
- 복사 / 드래그(NSItemProvider→Finder·Slack·Discord·ChatGPT·Claude·메일) / 공유시트 /
  핀(항상 위) / 호버 툴바 / 자동소멸 타이머 / 히스토리 단위 토글.
- **DoD**: Shelf 항목에서 모든 액션 동작. 드래그로 타 앱 전달.

## Sprint 3 — 저장소 + OCR + 텍스트 검색
- SQLite+FTS5 Repo(DATABASE.md), Vision OCR(OCR_ENGINE.md), OCR 색인, 키워드 검색(SEARCH_ENGINE.md §2).
- **DoD**: 이미지 내 텍스트로 검색 → 결과 하이라이트. 100K 장 목표 성능.

## Sprint 4 — AI 이름변경/요약 (provider)
- AIService 추상화(AI_ARCHITECTURE.md), Foundation Models/OpenAI/Claude/Gemini/Ollama,
  이름변경 + 요약. 옵트인/키(Keychain)/비용제어.
- **DoD**: 옵트인 후 캡처 자동 이름변경 + 요약. 미옵트인 시 비활성.

## Sprint 5 — Smart Folder 자동 정리
- 앱/윈도우/도메인 감지, 폴더 규칙 엔진(FR-2), 디렉토리 구조, 자동 이동(원본 보존+실행취소).
- **DoD**: 캡처 후 자동으로 폴더 정리. Library 사이드바 실시간 반영.

## Sprint 6 — 검색/타임라인/컬렉션 UI
- LibraryWindow(마스터-디테일), 타임라인(SCREEN_STATES.md §4), AI 컬렉션, AI 의미검색(옵트인).
- **DoD**: 사이드바 폴더 + 타임라인 스크럽 + 컬렉션 동작.

## Sprint 7 — 정리/중복/메모/클립보드
- Auto Cleanup(N일→휴지통), 중복 탐지(pHash 95%), AI Notes, Smart Clipboard 히스토리.
- **DoD**: 라이프사이클 종료 동작. 실행취소 보장.

## Sprint 8 — 설정/프라이버시/URL/Dev Mode
- SettingsWindow(Information Architecture §1), 브라우저 URL 감지, Dev Mode(에러→검색→Claude),
  녹화 파일 정리.
- **DoD**: 차별화(Dev Mode/URL) + 전체 설정/프라이버시 동작.

## Sprint 9 — 랜딩 + 브랜드
- `web/` 정적 사이트(LANDING_PAGE.md), AppIcon/로고 확정(BRAND_GUIDE.md), 비교페이지.
- **DoD**: 다운로드 가능한 랜딩. 브랜드 일관성.

## Sprint 10 — 폴리시/애니메이션/공증 배포
- 애니메이션 튜닝(ANIMATION_SPEC.md), 접근성 최종, Hardened Runtime, 공증/스테이플, DMG.
- **DoD**: 공증된 .dmg 배포 가능. 게이트+EVAL 전 PASS.

## 의존성

```
1 → 2 → 3 → 4 ─┐
        3 → 5 → 6 → 7      (5 는 3/4 에 의존 가능하나 3 만 필수)
                          8 (독립 가능, 6 이후 권장)
                              9 (언제나 가능, 10 직전 권장)
                                  10 (전체 선행 필요)
```

## 리스크 게이트

- Sprint 5(정리 오분류): 미리보기+실행취소 필수 — 실패 시 원상복구 자동.
- Sprint 4(AI): Intel/macOS15 온디바이스 미지원 → 클라우드/Ollama fallback 기본.
- Sprint 10(공증): Apple ID/인증서 — 사용자 확인 필수.
