# Sprint 7: 정리/중복/메모/클립보드

## 구현 범위
- `AutoCleanup`: N일(기본 30) 경과 임시 항목 → 휴지통(`NSWorkspace.recycle`). 실행취소 보장
- `Deduplicator`: pHash(지각 해시) 95% 유사 그룹 → 보관본 1개 추천. 사용자 승인
- `AI Notes`: 항목별 메모(로컬 저장, DB 컬럼/테이블)
- `Smart Clipboard`: 복사한 이미지 pasteboard 히스토리(제한 캡처, 로컬)

### 파일(예상)
- `src/Service/AutoCleanup.swift`, `Deduplicator.swift`, `PerceptualHash.swift`
- `src/Repo/NotesRepository.swift`, `ClipboardHistoryRepository.swift`
- `App/Sources/Library/DuplicatesView.swift`, `NotesView.swift`, `ClipboardHistoryView.swift`

## GENERATOR가 완료해야 할 것
- [ ] pHash/그룹핑/실행취소 단위 테스트(합성 이미지)
- [ ] 휴지통 복구 경로 테스트
- [ ] Gate 1~5 통과

## EVALUATOR가 검증할 것
- [ ] 오래된 항목 → 휴지통 이동 + 복구 가능
- [ ] 유사 항목 → 추천 → 승인 후 보관본 1개
- [ ] 메모 저장/표시
- [ ] 통과 기준: "라이프사이클 종료 동작 + 실행취소 보장"

## 의존 Sprint
이전: Sprint 6

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-15 08:20 KST

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 46) |
| 2 | 빌드 (xcodebuild) | ✅ PASS | BUILD SUCCEEDED |
| 3 | SwiftLint --strict | ✅ PASS | 0 violations (72 files) |
| 4 | 테스트 커버리지 | ✅ PASS | 87.0% (Config 92.2 · Repo 92.3 · Runtime 84.0 · Service 84.9 · Types 97.5), 146/146 통과 |
| 5 | 빌드 성공 | ✅ PASS | - |

### 구현 완료 항목
- AutoCleanup + CleanupModel: 30일 경과 임시 항목 → NSWorkspace.recycle, 실행취소 지원
- PerceptualHash(pHash) + Deduplicator + DuplicatesModel/View: 유사 그룹 → 보관본 추천 → 승인
- ClipboardHistoryRepository + ClipboardHistoryModel/View: pasteboard 이미지 히스토리 (JSON, 로컬)
- NotesView: 항목별 메모 (ShelfItem.notes 컬럼 + 저장)
- 신규 테스트: PerceptualHash/Deduplicator/AutoCleanup/CleanupModel/DuplicatesModel/ClipboardHistoryRepository/ClipboardHistoryModel
