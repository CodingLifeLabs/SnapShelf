# Sprint 8: 설정/프라이버시/URL/Dev Mode

## 구현 범위
- `SettingsWindow`(Information Architecture §1): General / Capture&Folders / OCR&Search / AI / Privacy / Advanced
- `BrowserURLDetector`: 활성 브라우저(Chrome/Safari/Firefox/Arc) 탭 URL — AppleScript/접근성 기반(옵트인)
- `DevMode`: 에러 캡처 → OCR → 코드/오류 추출(정규식) → 검색(StackOverflow/GitHub) → Claude 실행 옵션 → 복사
- 녹화 파일(Recordings) 동일 루트 정리(스크린샷과 병행)
- 프라이버시 대시보드: 데이터 위치, 클라우드 전송 내역, 내보내기/초기화(2단계)

### 파일(예상)
- `App/Sources/Settings/*` (탭별 뷰)
- `src/Service/BrowserURLDetector.swift`, `DevModeService.swift`, `RecordingOrganizer.swift`
- `src/Runtime/PrivacyLog.swift`

## GENERATOR가 완료해야 할 것
- [ ] URL 감지/DevMode/설정 영속 단위 테스트
- [ ] 위험 동작(초기화) 2단계 확인 + 원본 보존
- [ ] Gate 1~5 통과

## EVALUATOR가 검증할 것
- [ ] 각 설정 탭 표시/저장/복원
- [ ] URL 감지(옵트인) → 검색 결과에 URL 표시
- [ ] DevMode: 샘플 에러 캡처 → 코드 추출 → 검색/실행
- [ ] 초기화 2단계 확인 동작
- [ ] 통과 기준: "전 설정 + 차별화(Dev Mode/URL) 동작"

## 의존 Sprint
이전: Sprint 7 (Sprint 6 이후 권장)
