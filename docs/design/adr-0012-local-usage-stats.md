# ADR-0012: 로컬 사용 통계 — 텔레메트리 없는 PMF 지표

- **상태**: Proposed (Sprint 12)
- **결정일**: 2026-08-18

## 배경

`docs/pmf.md` 검증 지표(핵심 루프 반복, "다시 찾기" 성공률)는 텔레메트리 없이는 수집이
불가능하다. 그러나 SnapShelf 의 핵심 가치는 local-by-default 이며, 사용자 신뢰를
깨는 원격 전송은 선택지가 아니다. 동시에 v0.1.1 베타에서 다운로드 3회·피드백 0건으로
제품 개선의 근거 자체가 부족한 상태다.

## 결정

1. **사용 이벤트를 로컬 파일에만 기록한다** — `UsageStatsLog` actor (JSON lines,
   `~/Library/Application Support/SnapShelf/usage-stats.jsonl`, 최대 2000 events).
   PrivacyLog(Sprint 8)와 동일한 패턴·보안 수준.
2. **이벤트 종류**: `captured / searched / searchHit / copied / pinned / stowed`.
   스크린샷 내용·파일명·OCR 텍스트는 절대 포함하지 않는다 — 종류+타임스탬프만.
3. **집계는 순수 함수**(Service) — UI 는 Settings → Privacy 탭 하단에 표시.
   별도 탭을 만들지 않아 IA(6탭)를 유지한다.
4. **기록 자체는 상시** — 별도 옵트인 토글 없음. 근거: 데이터가 기기를 절대 떠나지
   않고 Privacy 대시보드에서 삭제 가능하며, PrivacyLog 도 동일 구조다. 사용자가
   원하면 Reset 으로 전체 삭제된다.
5. **원격 익명 전송은 영구 Scope Out** — 향후 요청 시 별도 옵트인 + 신규 ADR 필요.

## 근거

- 텔레메트리 금지는 제품 정체성(local-by-default). 지표 수집은 "사용자가 스스로
  확인하는" 형태로만 정당화된다.
- PrivacyLog 패턴 재사용으로 신규 인프라(서버·스키마 마이그레이션) 비용 0.
- SQLite 스키마 변경 없음 — 이벤트 로그는 파일이므로 `schema_meta` 버전 bump 불필요.

## 결과

- (Sprint 12 완료 후 기록)
