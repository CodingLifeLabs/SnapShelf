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

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-15 08:45 KST

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 55) |
| 2 | 빌드 (xcodebuild) | ✅ PASS | BUILD SUCCEEDED |
| 3 | SwiftLint --strict | ✅ PASS | 0 violations (86 files) |
| 4 | 테스트 커버리지 | ✅ PASS | 87.5% (Config 90.0 · Repo 92.3 · Runtime 85.1 · Service 85.6 · Types 98.2), 177/177 통과 |
| 5 | 빌드 성공 | ✅ PASS | - |

### 구현 완료 항목
- AppSettings + AppSettingsStore (UserDefaults 단일 키 JSON 스냅샷, 마이그레이션 용이)
- SettingsWindow 6탭 (General / Capture & Folders / OCR & Search / AI / Privacy / Advanced) + 메뉴바 "Settings…" 진입점
- BrowserURLDetector: 4개 브라우저 AppleScript 기반 탭 URL 조회, 스크립트 러너 주입 가능(테스트 가능)
- DevModeService: OCR 텍스트 → 코드 블록/에러 라인/파일 참조 추출(정규식, 완전 오프라인) → 검색 URL(SO/GH site:) / Claude URL 생성
- RecordingOrganizer: 녹화 파일(.mov/.mp4/.m4v) 월 버킷 정리
- PrivacyLog: 아웃바운드 전송 이력 JSONL 저장 (최대 500건 캡, newest-first)
- 초기화 2단계 확인 UI 프레임 (wipeStage idle → confirmWipe)
- 신규 테스트 31건: BrowserURLDetector 6 · DevModeService 10 · RecordingOrganizer 6 · PrivacyLog 5 · AppSettings 5
