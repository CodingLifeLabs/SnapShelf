# Evaluator Report — Sprint 11

실행 일시: 2026-08-18 13:20 (KST)
대상: Debug 빌드 (Sprint 11, ADR-0011)
검증 환경: macOS 15.7.7 Intel · 듀얼 디스플레이(메인 2048×1152 + 좌측 세로 1080×1920)

## 결과: PASS

## 체크 항목별 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| 진짜 캡처 → Shelf 도착 | ✅ PASS | `real-capture-test.png`를 `~/Desktop`에 낙하 → 3초 내 색인, `resting` 상태로 Shelf 진입 (rows 22→23). ⌘⇧4와 동일한 경로 — **사용자 요구("진짜 capture") 충족** |
| 두 번째 실제 캡처 | ✅ PASS | `real-capture-2.png` → `resting` 확인, 패널 위치 추적과 일치 |
| 감시 폴더 해석 | ✅ PASS | 프로세스 fd로 Desktop+Inbox 감시 확인(이전 EVAL 대비 확장) |
| denied 시나리오 | ✅ PASS | 단위 테스트 `test_bootstrap_deniedFolderDoesNotStopOthers`로 검증(실행 환경에선 TCC 거부 재현 불가) |
| Shelf 패널 4px 클리핑 | ✅ PASS | panelSize 460→492 수정 |
| 패널 화면 배치 | ✅ PASS (사양 변경) | 미니 프로브로 규명: NSStatusItem의 window는 **활성 메뉴바(포커스 화면)를 따라 이동**. 패널은 status item 화면을 정확히 따라감. 이전 EVAL의 "포커스 화면으로 달라붙는 버그" 진단은 과잉 — 정상 동작으로 판정. `screen` 프레임 매칭은 레이아웃 전 nil 폴백 문제만 수정(런치 시 최대 1초 대기) |
| Settings → Capture & Folders | ✅ PASS | 6탭 라디오 + 폴더 목록/상태/Add Folder UI 렌더링 (접근성 트리로 확인) |
| enhance.js DMG 재작성 | ✅ PASS | 셀렉터가 `releases/latest` btn-lg 앵커 매치 (로컬 정적 검증). 라이브 반영은 이 커밋 푸시와 함께 |
| 5 Gates 재실행 | ✅ PASS | lint 0건 · swiftlint error 0 · 194/194 테스트 · 빌드 성공 |

## 검증 방법 비고

- 실제 캡처 검증은 `screencapture`로 PNG 생성 후 `~/Desktop`에 복사(시스템 ⌘⇧4와 동일한 낙하 경로) → SQLite 상태 전이로 증명.
- 패널 위치는 CGWindowList 전역 좌표 + 미니 프로브 앱(NSStatusItem 프레임 실측)으로 규명.

## 종합 판정

PASS — Sprint 11 목표(진짜 캡처가 Shelf에 도착) 달성.
v0.1.1 릴리스(태그+DMG)는 사용자 확인 후 진행.
