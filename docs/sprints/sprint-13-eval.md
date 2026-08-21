# Evaluator Report — Sprint 13

실행 일시: 2026-08-20 ~ 2026-08-21 (세션 분할: 화면 잠금으로 일시 중단 후 재개)
검증 대상: Debug 빌드 (`DerivedData/.../SnapShelf.app`) — commit `25ae106`
검증 방법: 실제 `screencapture` 캡처 + SQLite 직접 조회 + System Events AX UI 조작

## 결과: PASS

## 체크 항목별 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| auto-stow 끄기 → 새 캡처 5초 후에도 resting | ✅ PASS | 토글 OFF 직후 캡처 → t+8s `status=resting` (S12 결함 재현 안 됨) |
| 다시 켜기 → 재스케줄 정책 | ✅ PASS (ADR 기준) | 기존 resting 항목이 재무장되어 신규 hover 창 후 stow. 계약서 괄호 주석("기존 소급 stow 안 함")과 반대 동작 — 아래 정책 노트 참조 |
| hoverSeconds 5→15 반영 | ✅ PASS | t+7s resting (구 5s 정책이면 이미 stow) → t+18s stowed = 15s 창 준수 |
| 실제 스크린샷 → 행 1건만 | ✅ PASS | 캡처마다 정확히 1행 등록. 46행 = 46 고유 source_url. dotfile(`.Name.png`) 중복 행 없음 |
| 캡처 후 ocr_text ≥ 1 | ✅ PASS | 완성된 파일 OCR 성공: 753자 / 1636자 추출, `ocr_status=ok` |
| 손상 PNG → 행 존재 + ocrStatus=failed | ✅ PASS | PNG 헤더+가비지 파일 → 행 저장(`stowed`) + `ocr_status=failed` — 침묵 아님 |
| 기존 기능 회귀 없음 | ✅ PASS | FTS 검색 정상(`MATCH 'warp'` 발췌 반환), 스키마 v2→v3 마이그레이션으로 기존 41행 보존, 감시·인테이크·설정 탭 전부 동작 |

## 시나리오 상세

### 1. 설정 전파 (결함 #1 — S12 "settings not propagated")

General 탭 토글을 실행 중 AX 클릭으로 전환하며 라이브 전파 확인:

1. **auto-stow OFF**: `defaults`에 `autoStow=false` 저장 + 캡처한 항목이 hover 창 후에도
   `resting` 유지 (구현: `applyShelfSettings`가 `stowWork` 전체 취소).
2. **재활성화**: 기존 resting 항목(`satart`)이 재무장 → 신규 5s 창 경과 후 `stowed`.
   신규 캡처도 정상 auto-stow.
3. **hoverSeconds 5→15**: Stepper를 AXIncrement로 10회(참조가 값마다 재생성되어 매번 재탐색).
   t+7s `resting` / t+18s `stowed` — 15초 창이 실제 적용됨.
   모든 변경이 `didSet → store.save → onShelfSettingsChanged → applyShelfSettings` 즉시 전파.

### 2. 인테이크 안정화 (결함 #2 — S12 "silent OCR failure")

- **dotfile 방어**: `screencapture`가 `.Name.png` 임시파일을 먼저 쓰고 rename하는 패턴에서
  행이 1건만 등록됨 (DirectoryWatcher가 점두파일 제외).
- **settle 대기**: 캡처 직후 행의 `ocr_text`가 채워짐 — 쓰기 중 파일을 읽는 레이스 제거.
- **OCR 실패 가시화**: 손상 PNG → 행 저장 + `ocr_status=failed` + `ocr_text` NULL.
  S12의 "죽은 행"(텍스트 없음 + 원인 불명)과 달리 실패가 식별 가능.

### 3. 스키마 마이그레이션 (v2→v3)

기존 41행이 든 실사용 DB에서 앱 기동 시 `ocr_status` 컬럼 자동 추가 확인
(`PRAGMA table_info` + `schema_meta.version=3`). 기존 행은 `ocr_status=NULL` — 하위호환.

## 정책 노트: 재스케줄 vs 소급 stow (계약서 불일치)

Sprint Contract의 EVAL 항목은 "기존 resting 항목 소급 stow 안 함"이라 기대했으나,
구현 범위·ADR-0013은 "resting 항목 재스케줄"을 명시했고 실제 동작도 재스케줄이다.
동작 자체는 일관되고 합리적(재활성화 시 새 hover 창으로 재무장)이므로 ADR을
진실의 원천으로 보아 PASS로 판정한다. 추후 계약서 문구 정리 권장.

## EVALUATOR 부록 — 재현 팁

- 화면 잠금 상태(`CGSSessionScreenIsLocked=True`)에선 screencapture/CGEvent가
  조용히 실패한다 ("could not create image from display …"). 잠금 해제 후 재개.
- python `CGEventPost`는 TCC 권한이 없으면 무음으로 무시된다. osascript(System Events)는
  권한이 있으므로 신뢰 가능 — `click`/`perform action "AXIncrement"` 사용.
- SwiftUI Stepper의 incrementor 참조는 값 변경마다 재생성된다: 증감마다
  `entire contents`를 다시 열거해 새 참조를 얻을 것.
- LSUIElement 앱의 AX 창 목록은 frontmost일 때만 보인다.

## 종합 판정

PASS — Sprint 12 EVAL에서 발견된 결함 2건 모두 실사용 시나리오에서 수정 확인.
회귀 없음. 다음 스프린트 진행 가능.
