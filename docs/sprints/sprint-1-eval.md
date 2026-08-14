# Evaluator Report — Sprint 1

실행 일시: 2026-08-14
검증 대상: SnapShelf.app (Debug, ad-hoc signed)

## 결과: PASS

## 검증 방법
`Playwright`/웹 EVAL이 아닌 네이티브 앱이므로, `xcodebuild` 빌드 + `open` 실행 +
`CGWindowList` 윈도우 검증 + **라이브 inbox 투하 → index.json 갱신** 기능 검증을 사용.
(스크린샷 캡처는 이 환경의 TCC 화면녹화 권한 제한으로 셸에서 차단됨 — 앱 결함 아님.)

## 체크 항목별 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| 빌드 → `.app` 산출 | ✅ PASS | BUILD SUCCEEDED, SnapShelf.app 생성 |
| 실행 (메뉴바 액세서리) | ✅ PASS | 프로세스 정상 기동 (LSUIElement) |
| 메뉴바 상태 아이템 | ✅ PASS | CGWindowList: owner=SnapShelf, layer=25, onScreen=true (상단 우측 33×24) |
| Shelf 패널 표시 | ✅ PASS | CGWindowList: owner=SnapShelf, layer=3(floating), 340×488, 우하단 고정 |
| 핵심 루프 (캡처→Shelf→영속) | ✅ PASS | inbox에 PNG 투하 → 자동 감시 → 파이프라인 → index.json 색인 확인 |
| 영속 데이터 정합성 | ✅ PASS | index.json: id/status/displayName/sourceURL 올바름 |
| 두 번째 실행에서 load() | ✅ PASS | 기존 index.json 항목이 패널에 로드(빈 상태 아님) |

## EVAL 중 발견·수정된 버그 (Strike 없이 자가 수정)
- **NSPanel 자가 은닉**: 액세서리 앱 비활성화 시 패널이 사라짐 → `hidesOnDeactivate = false`
  + `NSApp.activate()` 로 수정 후 패널 정상 표시 확인(1회 내 수정, EVAL 재시도 0회).

## 환경 제한 (기록)
- `screencapture`(셸) 가 TCC 화면녹화 권한 미허용으로 동작하지 않음.
  → 시각 회귀는 향후 XCUITest 또는 권한 부여 환경에서 보완 예정(SCREEN_STATES.md).
- 본 검증은 기능적·구조적 증거로 수용 기준(메뉴바+패널+핵심루프 동작)을 모두 충족.

## 종합 판정
**PASS** — 다음 Sprint(2: Shelf 인터랙션) 진행.
