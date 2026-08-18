# ADR-0011: 실제 스크린샷 폴더 감시 (Real Folder Watching)

- 상태: Accepted (v0.1.1)
- 일자: 2026-08-18
- 배경: 2026-08-18 대화형 EVAL에서 CRITICAL 확인 — 앱이 자체 Inbox만 감시하여
  실제 ⌘⇧4/LWScreenShot 캡처(→ `~/Desktop`)가 Shelf에 도달하지 않음. spec P0-2 미구현.

## 결정

1. **다중 폴더 감시**: `DirectoryWatcher`를 폴더별 인스턴스로 확장 생성.
   기본 감시 대상(자동 감지, 중복 제거):
   - `defaults read com.apple.screencapture location` 값(설정된 경우)
   - `~/Desktop` (설정 미지정 시 macOS 기본 저장 위치)
   - `~/Pictures/Screenshots` (존재하는 경우)
   - 앱 소유 `Inbox`(기존 동작 유지, 시뮬레이션·내부 경로)
   - 사용자 추가 폴더(AppSettings에 영속)
2. **TCC 정책**: 앱은 비샌드박스(ad-hoc 서명)이므로 보안-스코프 북마크 불필요.
   보호 폴더(Desktop/Pictures/Downloads)는 최초 접근 시 시스템 TCC 프롬프트.
   Info.plist usage description은 Sprint 1부터 이미 존재.
3. **거부 처리**: 폴더 열거 실패/빈 결과 반환 시 해당 폴더를 `denied` 상태로 표시하고
   나머지 폴더는 계속 감시. 앱 전체가 죽지 않음. Settings에서 재시도 안내.
4. **기존 파일 무시**: 감시 시작 시점의 존재 파일은 시딩만 하고 색인하지 않는다
   (기존 DirectoryWatcher 동작 유지 — Desktop의 과거 스크린샷 대량 유입 방지).
5. **앱 소유 경로 보호**: 사용자 추가 폴더 목록에서 Inbox/Library/Recordings 및
   그 하위 경로는 거부(이중 색인 방지).

## 대안 검토

- **ScreenCaptureKit 직접 캡처**: ADR-0003에서 기각(시스템 단축키 결과물 감시가 더 견고).
  본 ADR은 ADR-0003의 원래 의도를 구현하는 것.
- **샌드박스+보안스코프북마크**: 현재 서명 체계(ad-hoc)와 불일치, 불필요한 복잡도.

## 결과

- ⌘⇧4 캡처 → 감시 폴더에 파일 낙하 → 기존 IntakePipeline(OCR→AI이름→정리→색인) 재사용.
- 코드 변경: Config(폴더 해석+설정), Runtime(ShelfModel 다중 워처), App(설정 UI),
  ShelfPanelController(위치 수정 부수 반영).
