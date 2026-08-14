# SnapShelf — Product Requirements Document (PRD)

> 버전 0.1 · 2026-08-14 · 작성: PLANNER

## 1. 비전

> **The fastest way to capture, organize and rediscover your screenshots.**

스크린샷은 찍는 순간엔 유용하지만, 10분 뒤엔 "어디 갔지?" 가 된다.
Sukurini 는 "잠깐 보관(Shelf)" 으로 출발점을 잡았고, CleanShot X 은 캡처/편집/OCR 을 다룬다.
하지만 **아무도 "나중에 다시 찾기" 를 제대로 해결하지 못했다.**

SnapShelf 는 스크린샷의 **전체 라이프사이클**을 한 앱에서:

```
Capture → Shelf → AI → Organize → Search → Archive → Delete
```

## 2. 타깃 사용자

1. **개발자** — 에러/로그/API 문서/터미널 캡처를 나중에 검색·Dev Mode 로 재활용.
2. **디자이너/PM** — 영감/레퍼런스/회의 자료를 프로젝트별로 자동 분류.
3. **지식 노동자** — 청구서/영수증/문서 캡처를 AI 컬렉션으로 보관.

공통 고통: **"분명 캡처했는데 못 찾겠다"** + **"바탕화면이 스크린샷으로 넘쳐난다"**.

## 3. 핵심 가치 제안

| 차원 | Sukurini | CleanShot X | **SnapShelf** |
|------|----------|-------------|---------------|
| Shelf 임시 보관 | ✅ | ❌ | ✅ |
| OCR | ❌ | ✅ | ✅ |
| AI 가공(이름/요약/분류) | ❌ | ❌ | ✅ |
| 자동 폴더 정리 | ❌ | ❌ | ✅ |
| 전문 검색(FTS5) | ❌ | △ | ✅ |
| 타임라인/컬렉션 | ❌ | ❌ | ✅ |
| 오프라인 우선 프라이버시 | ✅ | ✅ | ✅ |

## 4. 기능 요구사항 (FR)

### FR-1 Capture & Shelf
- FR-1.1 시스템 스크린샷(⌘⇧4/⌘⇧5) 파일을 FSEvents 로 감시하여 자동 수집.
- FR-1.2 캡처 직후 우하단에서 Shelf 로 빨려드는 애니메이션(≤200ms).
- FR-1.3 Shelf 항목: 5초간 떠 있음(설정 가능), 호버 시 툴바 노출.
- FR-1.4 Shelf 항목 액션: 복사 / 드래그(Finder·Slack·Discord·ChatGPT·Claude·메일) / 공유 / 핀(항상 위) / OCR / AI 요약.
- FR-1.5 History: 최근 10/50/100/무한 단위 토글.

### FR-2 Smart Folder (자동 정리)
- FR-2.1 앱 이름 기반 분류(활성 창 메타데이터 / 파일명 휴리스틱).
- FR-2.2 디렉토리 구조 예: `Screenshots/2026/08/Chrome/...` 또는 `Screenshots/ChatGPT/...`.
- FR-2.3 프로젝트 단위 분류(AI 가 동일 프로젝트/웹사이트/코드 판단).
- FR-2.4 규칙 엔진: 사용자 규칙(정규식/앱/태그) + AI 제안 규칙.

### FR-3 OCR & Search
- FR-3.1 Vision OCR 로 이미지 내 텍스트 추출·색인.
- FR-3.2 SQLite + FTS5 전문검색. 예: `"Supabase"` → 해당 스크린샷.
- FR-3.3 자연어 AI 검색. 예: `"지난달 ChatGPT 에서 본 API"`.
- FR-3.4 100,000장 기준 검색 응답 ≤ 150ms.

### FR-4 AI (선택·옵트인)
- FR-4.1 AI 이름변경: `Screenshot 2026-08-14...png` → `Supabase Login Error.png`.
- FR-4.2 AI 요약: 긴 문서 캡처 3줄 요약.
- FR-4.3 AI 분류/컬렉션/중복 추천.
- FR-4.4 provider: Foundation Models(온디바이스) / OpenAI / Claude / Gemini / Ollama.

### FR-5 Timeline & Collections
- FR-5.1 시간순 타임라인(오늘 오전 회의 → Slack → VSCode → Chrome → Claude → Figma).
- FR-5.2 동일 주제 자동 컬렉션(예: Supabase 스크린샷 20장).

### FR-6 Dev Mode
- FR-6.1 VSCode 에러 → OCR → 오류 코드 추출 → 검색 → Claude 실행 → 복사.

### FR-7 Browser/URL 감지
- FR-7.1 캡처 시 활성 브라우저 탭 URL 저장. 검색: `"Supabase migration"` → 당시 URL 표시.

### FR-8 Lifecycle
- FR-8.1 Auto Cleanup: N일 경과 임시 스크린샷 휴지통(기본 30일).
- FR-8.2 중복 탐지(95% 유사) 삭제 추천.
- FR-8.3 녹화(Recordings) 동일 루트 정리.
- FR-8.4 AI Notes(항목별 메모) · Smart Clipboard(이미지 복사 히스토리).

## 5. 비기능 요구사항 (NFR)

- **NFR-1 성능**: Shelf 진입 ≤200ms / 검색 ≤150ms(100K장) / 상주 메모리 ≤120MB.
- **NFR-2 프라이버시**: 기본 오프라인. 클라우드 AI 시 해당 항목만 전송, 설정에 명시.
- **NFR-3 접근성**: VoiceOver·키보드 전용·reduce-motion. APPLE_HIG.md 준수.
- **NFR-4 안정성**: 권한/OCR/AI 실패 시 원본 보존 + 사용자 알림.
- **NFR-5 호환**: macOS 14.0+, Intel + Apple Silicon.

## 6. 성공 지표 (KPI)

- 핵심 루프 일일 반복: 평균 유저 하루 캡처→Shelf 재접근 ≥3회.
- "다시 찾기" 성공률: 검색→클릭/드래그 전환 ≥40%.
- 정리 적중률: Smart Folder 자동 분류 정확도 ≥85%.
- 바탕화면 스크린샷 감소: 사용 1주 후 ≥60%.

## 7. 릴리즈 마일스톤

- **M1 (Sprint 1–2)**: Shelf UX 동작 (캡처→Shelf→드래그/복사/공유). 내부 알파.
- **M2 (Sprint 3–4)**: 검색 + AI 가공 동작. 프라이빗 베타.
- **M3 (Sprint 5–7)**: 자동 정리 + 라이프사이클 완결. 퍼블릭 베타.
- **M4 (Sprint 8–10)**: 차별화 완성 + 랜딩 + 공증 배포. 정식 출시.

## 8. 리스크

- **R1 권한(TCC)**: Desktop/Pictures 접근 거부 시 감시 불가 → 온보딩에서 명확 안내 + 폴백(직접 폴더 지정).
- **R2 온디바이스 LLM(Intel/macOS15)**: Foundation Models 미지원 → 클라우드/Ollama fallback.
- **R3 정리 오분류**: 자동 이동 전 미리보기 + 실행취소 보장.
- **R4 경쟁**: 기존 도구가 AI 를 추가할 수 있음 → 속도·통합도·오프라인 우선으로 차별.
