# 대화형 EVAL 보고서 — 2026-08-18

> v0.1.0(acccb61) 배포 후 첫 대화형 환경 검증.
> 환경 변화: 셸 `screencapture` TCC 허용됨(이전 세션 차단) → 시각 검증 가능.
> System Events 접근성 스크립팅으로 메뉴 클릭 자동화 가능.

## 검증 방법

- Debug 빌드(BUILD SUCCEEDED) → `open` 실행 → CGWindowList 윈도우 확인
- osascript로 메뉴 액션 트리거 + `screencapture -R` 프레임 캡처
- SQLite(`index.sqlite`) 직접 조회로 상태 전이 확인
- Playwright로 랜딩 페이지 렌더링·CTA 확인

## 결과 요약

| # | 항목 | 결과 |
|---|------|------|
| 1 | 빌드·실행·메뉴바+패널 윈도우 | ✅ |
| 2 | 코어루프(파일→OCR→AI이름→색인) | ✅ EvalProof PNG 색인, FTS5 MATCH 히트 |
| 3 | Simulate Capture → Shelf 등장 | ✅ +2.5s 프레임에 신규 항목 관측 |
| 4 | auto-stow(hoverSeconds=5) | ✅ +8s 프레임에서 소멸, DB `stowed` 전이 |
| 5 | Library 창(사이드바/그리드/타임라인) | ✅ 렌더링 확인 |
| 6 | Settings 6탭 | ✅ (코드 확인: General/Capture/OCR/AI/Privacy/Advanced) |
| 7 | 랜딩 페이지 + Download CTA | ✅ (버그 1건 — 아래) |

**전체 판정: 조건부 PASS** — 자동화 가능 범위는 전부 통과. 아래 결함은 별도 수정 필요.

## 발견 결함

### CRITICAL — 실제 스크린샷 폴더 미감시 (spec P0-2 미구현)

- 앱은 `~/Library/Application Support/SnapShelf/Inbox`만 감시한다.
- 사용자 스크린샷 저장 위치: `~/Desktop`(LWScreenShot·시스템 스크린샷 확인).
- → **⌘⇧4/LWScreenShot 캡처를 찍어도 SnapShelf에 아무 일도 일어나지 않는다.**
  "실제로 캡처가 되는 것 같지 않다"는 지적의 직접 원인.
- 랜딩은 "desktop에 쌓이는 스크린샷" 문제를 팔고 있어 기대-경험 불일치.
- 경위: Sprint 5에서 "TCC-safe path로 범위 조정, user-folder watch deferred"
  (CHANGELOG) 이후 회귀하지 못함. `Capture & Folders` 설정 탭도 경로 표시만 가능.
- 권장: v0.1.1 최우선. 보안-스코프 북마크 + TCC 안내 + 폴백 유지.

### BUG — 랜딩 enhance.js DMG 직접링크 재작성 데드코드

- `web/assets/enhance.js`: `a[href="#download"]` 중 `btn-lg`만 재작성하지만
  정작 `btn-lg` CTA의 초기 href는 `releases/latest` → 셀렉터 미매치.
- 영향 경미(누락 시에도 releases/latest로 1회 추가 클릭), 그러나 의도(다이렉트 DMG) 미달성.

### CRITICAL — 랜딩 CSS 미로딩 (사용자 제보, 2026-08-18 수정됨)

- `web/index.html`이 절대경로 `/assets/*.css` 를 참조 → 프로젝트 사이트
  (`.../SnapShelf/` 하위 배포)에서 org 루트로 해석되어 404, **스타일 없는 글씨만 렌더링**.
- `href="/assets/…` 5건 + `href="/"`(브랜드) → 상대경로 `assets/…` / GitHub 저장소 링크로 수정.
- 검증: 로컬 하위 경로 서빙 재현으로 200 확인. (Playwright 헤드리스 캡처는
  파일/캐시로 자산이 로드되어 사전 발견 실패 — 실브라우저 제보로 포착.)

### POLISH — Shelf 패널 배치

- `ShelfPanelController.show()`가 `NSScreen.main`(포커스 스크린) 기준 배치 →
  실행 시 포커스가 보조 디스플레이에 있으면 패널이 그쪽으로 감(관측: X=1684→−364).
- 컨트롤러 panelSize 460 vs SwiftUI 콘텐츠 실측 488 → 하단 4px 클리핑.
- 권장: `NSScreen.screens.first` 또는 상태바 아이콘 위치 기준 + 콘텐츠 높이 반영.

### MINOR

- `index.json`(storeFile)은 Sprint 3 이전 유물로 잔존 — 혼동 여지(무해).
- 합성 바 패턴 OCR이 "SII.NL"로 인식 → RuleBased AI 이름 파생. 실사용 텍스트에선 정상.

## 다음 액션 제안

1. v0.1.1 스프린트: P0-2 실제 폴더 감시(보안-스코프 북마크) — PMF상 필수
2. enhance.js 셀렉터 수정(1줄)
3. 패널 배치 수정(스크린 선택 + 높이)
4. 위 3건은 신규 PLANNER 사이클 or 핫픽스로 진행 여부 결정 필요
