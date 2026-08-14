# Sprint 2: Shelf 인터랙션

## 구현 범위
- 드래그: `NSItemProvider`(PNG 파일 + 파일 URL) → Finder/Slack/Discord/ChatGPT/Claude/메일 전달
- 복사(⌘C): 이미지 → pasteboard
- 공유: `NSSharingServicePicker`(AirDrop/메일/메시지/Notes)
- 핀: 항상 위 고정(상단 "Pinned" 섹션)
- 호버 툴바: 복사/드래그핸들/공유/OCR(스텁)/AI(스텁)/핀 (ANIMATION_SPEC §2)
- 자동 소멸 타이머: 설정 호버 시간 후 히스토리로(ANIMATION_SPEC §3)
- 히스토리 단위 토글: 10/50/100/∞

### 파일(예상)
- `App/Sources/Shelf/ShelfItemView.swift`(확장: 툴바, 드래그, 핀)
- `App/Sources/Shelf/ShelfPanelView.swift`(Pinned 섹션, 토글)
- `src/Runtime/ShelfCoordinator.swift`(소멸 타이머, 핀 상태)
- `src/Service/ClipboardService.swift`(pasteboard 복사) + 테스트

## GENERATOR가 완료해야 할 것
- [ ] 위 기능 구현 + 단위 테스트(ClipboardService 등 순수 로직)
- [ ] Gate 1~5 통과(커버리지 ≥80%)
- [ ] reduce-motion 시 액션은 정상(애니메이션만 단축)

## EVALUATOR가 검증할 것
- [ ] Shelf 항목 호버 → 툴바 노출
- [ ] 드래그 → Finder 창에 파일 드롭 성공
- [ ] 복사 → 다른 앱에 붙여넣기 성공
- [ ] 공유 시트 정상 노출
- [ ] 핀 → 상단 고정 유지
- [ ] 소멸 타이머 후 히스토리로 이동
- [ ] 통과 기준: "모든 Shelf 액션이 실제로 동작"

## 의존 Sprint
이전: Sprint 1

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-14

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 15) |
| 2 | 빌드/컴파일 | ✅ PASS | 오류 0건 |
| 3 | SwiftLint(--strict) | ✅ PASS | error 0건 (66파일) |
| 4 | 테스트 커버리지 | ✅ PASS | 42/42 통과, 전체 95.0% (Config 90 · Repo 98 · Runtime 94 · Service 97 · Types 100) |
| 5 | 빌드 성공 | ✅ PASS | 경고 0건 |

