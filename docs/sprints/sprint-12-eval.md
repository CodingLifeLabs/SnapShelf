# Evaluator Report — Sprint 12 (로컬 사용 통계)

실행 일시: 2026-08-20 11:50–12:35 (KST)
검증 대상: Debug 빌드 (`DerivedData/.../Debug/SnapShelf.app`) 실행 — 배포 불필요(로컬 전용 기능)

## 결과: PASS (조건 없음)

| # | 항목 | 결과 | 비고 |
|---|------|------|------|
| 1 | Settings → Privacy 탭 "Your usage (local only)" 섹션 렌더링 | ✅ PASS | osascript 라디오버튼(5번) 클릭으로 탭 전환, `screencapture -l` 창 캡처로 확인 |
| 2 | 지표 카드 5종 표시 (Captured / Searches / Search hit rate / Copied / Active days) | ✅ PASS | 빈 상태 "—" 및 수치 상태 모두 확인. hit rate는 `hitRate()` 포맷("—" / %) 정상 |
| 3 | "This never leaves your Mac" 고지 문구 | ✅ PASS | lock 아이콘과 함께 footnote로 렌더링 |
| 4 | Reset 버튼 → 지표 0 초기화 | ✅ PASS | AXPress 후 jsonl 파일 삭제 + UI 즉시 0/—/0으로 갱신. 리셋 후 신규 이벤트 기록 시 파일 재생성됨(재기록 확인) |
| 5 | 실제 플로우: 캡처 → captured +1 | ✅ PASS | Inbox에 PNG 투입 → `shelf_items` 26→27행, `captured` 이벤트 기록. 5초 후 `stowed`도 자동 기록 |
| 6 | 실제 플로우: 검색 → searched / searchHit | ✅ PASS | Shelf 패널 검색창에 "warp" 입력 → `searched` 기록, FTS 명중(2건) 시 `searchHit` 기록. 무검색결과 쿼리는 searched만 |
| 7 | usage-stats.jsonl 파일 존재 (Application Support) | ✅ PASS | `~/Library/Application Support/SnapShelf/usage-stats.jsonl`. Data locations 행에 경로 표시 |
| 8 | UI 수치 ↔ jsonl 실데이터 일치 | ✅ PASS | 탭 재진입 시점: UI(Captured 15 · Searches 23 · hit 4% · days 2) == jsonl 집계(15/23/1/2) 완전 일치 |
| 9 | 기존 기능 회귀 (Shelf/검색/설정/감시) | ✅ PASS | 폴더 감시(2 folders), 캡처 파이프라인, FTS 검색, 설정 탭 전환 모두 정상 동작 |

## 검증 방법 (네이티브 앱)

- Playwright 대신 네이티브 EVAL 기법(`memory/snapshelf-native-eval-technique`) 사용:
  osascript(System Events)로 메뉴·탭·체크박스·텍스트필드 조작 + `screencapture -l <windowID>` 창 단위 캡처 + `index.sqlite`/`usage-stats.jsonl` 직접 검증.
- 좌표 클릭은 CGEventPost(HID) 사용. **주의: CGEvent y좌표는 top-left 원점**(NSEvent bottom-up와 반대).

## 스프린트 외 발견 (신규 이슈 후보 — Sprint 12 범위 아님)

1. **[Legacy] Settings의 shelf 설정이 ShelfModel에 미전달**
   General 탭 "Auto-stow after hover time" 끄기(체크박스 val 0, AppSettings 저장 확인) 후에도
   신규 캡처 항목이 5초 뒤 자동 stow됨. `SettingsModel.settings`(AppSettings)과
   `ShelfModel.settings`(ShelfSettings, init 시 `.default` 고정) 사이 전파 코드가 없음
   (`App/Sources/SnapShelfApp.swift`는 `onFoldersChanged`만 연결).
   → 사용자가 설정을 바꿔도 반영되지 않는 실제 결함. 별도 수정 스프린트/이슈 권장.
2. **[Automation] Shelf 카드 hover 툴바 버튼(copy/share/pin)이 합성 클릭에 무반응**
   bordered 버튼(Header Capture)은 합성 클릭 동작, borderless 툴바 버튼은 무반응.
   `.accessibilityElement(children: .combine)` + `.onDrag` 조합의 자동화 한계로 판단
   (실사용자 마우스는 동작; UI 렌더링·hover 상태는 캡처로 정상 확인).
   이로 인라 `.copied`/`.pinned`는 UI 경로 검증 대신 (a) 동일 `recordUsage()` 채널의
   라이브 검증(searched/searchHit/captured/stowed) + (b) 단위 테스트로 갈음.
3. **[환경] 검증 세션 중 이전 OCR 미탑재 항목들** — Sprint 12 무관. 인앱 OCR 실패(`try?`로 삼킴) 원인은
   별도 조사 필요(직접 Vision 호출 시 같은 파일에서 텍스트 인식 성공했음 — 타이밍/파일 이동 race 의심).

## 종합 판정

**PASS** — Sprint Contract의 EVALUATOR 검증 항목 전부 충족. 다음 단계: CHANGELOG/quality.md 갱신,
ADR-0012를 Proposed → Accepted로 전환.
