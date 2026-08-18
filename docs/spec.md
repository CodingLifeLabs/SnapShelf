# Product Spec: SnapShelf

## 목적

스크린샷을 찍은 직후 잠깐 쓰고 "나중에 다시 찾을 수 없어" 지는 문제를 해결한다.
한 줄: **The fastest way to capture, organize and rediscover your screenshots.**

Sukurini 가 "잠깐 보관(Shelf)" UX 로 출발점을 만들었다면, SnapShelf 는
**Capture → Shelf → AI → Organize → Search → Archive → Delete** 전체 라이프사이클을
단일 네이티브 macOS 앱으로 다룬다. 핵심 차별점은 "자동 정리(Smart Folder) + OCR/AI 검색" 으로
**두 번째 물림(second-bite: 다시 찾기)** 을 만든다는 점이다.

## PMF 필터 통과 여부

| 기준 | 판정 | 근거 |
|------|------|------|
| 리텐션 임팩트 | ✅ | "스크린샷 다시 못 찾음" 은 매일 발생; Shelf 단독은 임시 보관에 그침 |
| 습관 형성(second-bite) | ✅ | 자동 정리 + 검색이 매일 재방문 유도 |
| Agentic 결과물 | ✅ | OCR·분류·이름변경·정리·중복삭제가 인간 개입 없이 동작 |

→ 3/3 충족. **통과.** 구현 진행.

## 기술 스택

- **Frontend/UI**: Swift 6.2 / SwiftUI + AppKit (macOS 14.0 Sonoma+)
- **Capture**: ScreenCaptureKit(주문 캡처) + FSEvents(스크린샷 폴더 감시)
- **OCR**: Vision `VNRecognizeTextRequest`(오프라인·무료·고정밀)
- **Search**: SQLite + **FTS5**(시스템 sqlite 포함). Repo 레이어.
- **AI**: provider 추상화 — Foundation Models(on-device, macOS 26+), OpenAI, Claude, Gemini, Ollama(로컬)
- **Shelf**: `NSStatusBar` + `NSPanel`(`.nonactivatingPanel`, always-on-top)
- **Drag**: `NSItemProvider` / SwiftUI `.draggable`

## 영향받는 레이어

전 레이어(Types / Config / Repo / Service / Runtime / UI). 거의 모든 Sprint 가 다수 레이어를 건드린다.

## 화면·기능 목록

### P0 (핵심 루프)
1. **Menu bar + Shelf 패널** — 캡처 직후 우하단→Shelf 애니메이션 진입. 복사/드래그/공유/핀.
2. **Screenshot folder watcher** — `~/Pictures/Screenshots`·`~/Desktop` FSEvents 감시.
3. **Smart Folder 자동 정리** — 앱/도메인/프로젝트 기반 폴더 규칙 엔진 + 자동 이동.
4. **OCR + FTS5 검색** — 이미지 내 텍스트 색인, 키워드 검색.

### P1 (차별화·두 번째 물림)
5. **AI 이름변경** — `Screenshot 2026-08-14...png` → `Supabase Login Error.png`
6. **AI 요약** — 긴 문서 캡처 3줄 요약.
7. **AI 검색** — "지난달 ChatGPT 에서 본 API" 자연어 검색.
8. **Timeline** — 시간순 재생(오늘 오전 회의 → Slack → VSCode → ...).
9. **Dev Mode** — VSCode 에러 OCR → 코드 추출 → 검색 → Claude 실행 → 복사.
10. **Browser/URL 감지** — 캡처 시 활성 탭 URL 저장, 검색에 활용.
11. **AI Collections** — 동일 주제(예: Supabase) 자동 컬렉션 생성.

### P2 (확장)
12. **AI 중복 탐지** — 95% 유사 화면 삭제 추천.
13. **Auto Cleanup** — 30일 경과 임시 스크린샷 휴지통.
14. **Screenshot Recorder 정리** — 녹화 파일도 동일 루트 정리.
15. **AI Notes** — 스크린샷 옆 메모.
16. **Smart Clipboard** — 복사한 이미지 히스토리.

## 비기능 요구사항

- **성능**: Shelf 진입 애니메이션 ≤ 200ms. 100,000장 FTS5 검색 ≤ 150ms. 메뉴바 상주 메모리 ≤ 120MB.
- **접근성**: VoiceOver 라벨, 키보드 전용 조작, 축소 동작(reduce-motion) 지원 — APPLE_HIG.md.
- **프라이버시**: 기본 오프라인. 모든 색인/이미지는 로컬. AI 는 명시적 옵트인(provider + 키 입력). 클라우드 전송 시 해당 항목만.
- **안정성**: 권한(TCC) 거부 시 우아한 폴백. OCR/AI 실패 시 원본 보존.

## 제외 범위 (Scope Out — v1)

- Windows/Linux 지원 (macOS 전용 네이티브)
- iOS 동기화 (v2 검토)
- 클라우드 스토리지 자체 호스팅 (로컬 우선)
- 실시간 화면 OCR 오버레이(별개 제품)

## Sprint 분해 요약

상세는 `docs/sprints/` 및 `ROADMAP.md`.

| Sprint | 범위 | 목표 |
|--------|------|------|
| 1 | Foundation (모듈·메뉴바·감시·Shelf) | 캡처→Shelf 등장이 동작 |
| 2 | Shelf 인터랙션 (드래그/복사/공유/핀) | Shelf 에서 바로 쓰기 |
| 3 | 저장소 + OCR + 텍스트 검색 | 10만장 검색 |
| 4 | AI 이름변경/요약 (provider) | AI 가공 |
| 5 | Smart Folder 자동 정리 | 폴더가 스스로 정리됨 |
| 6 | 검색/타임라인/컬렉션 UI | 다시 찾기 |
| 7 | 정리/중복/메모/클립보드 | 라이프사이클 완결 |
| 8 | 설정/프라이버시/URL/Dev Mode | 차별화 완성 |
| 9 | 랜딩 + 브랜드 | 다운로드 전환 |
| 10 | 폴리시/애니메이션/공증 | 배포 |
| 11 | 실제 폴더 감시 (ADR-0011) | 진짜 캡처 |
| 12 | 로컬 사용 통계 (아래 "기능 확장 — 로컬 사용 통계" 참조) | 셀프 리포트 PMF 지표 |

## 기능 확장 — 로컬 사용 통계 (Sprint 12, 2026-08-18 추가)

### 목적
PMF 검증 지표(핵심 루프 반복 횟수, "다시 찾기" 성공률)를 **텔레메트리 없이**
사용자가 스스로 확인할 수 있게 한다. 모든 데이터는 기기 내 로컬 파일 — 전송 0.

### 설계 결정 (ADR-0012)
- `UsageEventKind` enum: `captured / searched / searchHit / copied / pinned / stowed`
- `UsageStatsLog` actor (Runtime): PrivacyLog 과 동일한 JSON-lines 파일 패턴 재사용
- 집계는 순수 함수 `UsageStatsSummary.compute(events:)` (Service) — 테스트 용이
- 표시: Settings → Privacy 탭 하단 "Your usage (local only)" 섹션. 신규 탭 아님
- 이벤트 기록 자체는 별도 옵트인 없이 상시(파일은 로컬 전용, PrivacyLog 와 동일 보안 수준)

### PMF 필터 (이 확장)
- 리텐션 임팩트 ✅ (지표 없이는 PMF 판정 불가) · 습관 형성 △ (셀프 리포트) · Agentic ✅ (자동 집계)
→ 2/3 충족. 통과. 단, v2 (원격 익명 전송) 는 별도 옵트인·ADR 필요 — Scope Out.
