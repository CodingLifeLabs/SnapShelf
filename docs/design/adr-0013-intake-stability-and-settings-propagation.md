# ADR-0013: 설정 전파 + 인테이크 안정화 (Sprint 13)

- 상태: Accepted (Sprint 13 구현·EVAL PASS 2026-08-21)
- 일자: 2026-08-20
- 맥락: Sprint 12 EVAL(`sprint-12-eval.md`)에서 발견된 결함 2건의 근본 해결

## 문제 1 — Settings가 ShelfModel에 전달되지 않음

### 배경
- `SettingsModel.settings`(AppSettings, UserDefaults 저장)의 General 탭 편집
  (auto-stow/hoverSeconds)이 실제 동작에 반영되지 않음.
- `ShelfModel.settings`는 `let` + init 시 `ShelfSettings.default`로 고정.
- `SnapShelfApp.swift`는 `onFoldersChanged` 콜백만 연결 — shelf 설정 채널 없음.

### 결정
**단방향 콜백 주입** — `SettingsModel.onShelfSettingsChanged: (ShelfSettings) -> Void`
콜백를 `SnapShelfApp`에서 `ShelfModel.applyShelfSettings(_:)`로 연결한다.

```swift
// Runtime (ShelfModel)
public func applyShelfSettings(_ new: ShelfSettings)   // settings를 갱신 + 스케줄된 stow 재조정

// App (SnapShelfApp) — 기존 onFoldersChanged 옆에 추가
settingsModel.onShelfSettingsChanged = { [weak model, weak settingsModel] in
    guard let model, let settingsModel else { return }
    model.applyShelfSettings(settingsModel.settings.shelfSettings)
}
```

- `ShelfModel.settings`는 `let` → `private(set) var`로 변경 (외부 읽기 유지, 쓰기는 이 메서드만).
- `didSet` 기반 자동 전파는 Runtime이 AppSettings를 몰라야 하는 레이어 규칙상 불가 —
  콜백 주입이 레이어 규칙(단방향, 역방향 import 금지)과 양립하는 유일한 깔끔한 경로.
- 기각한 대안: (a) ShelfModel이 AppSettings 직접 참조 — Config→Runtime 역방향 아님(정방향)이나
  SettingsModel과 이중 소스 발생, (b) NotificationCenter — 암시적 결합, 테스트 불리.

## 문제 2 — 인테이크 레이스: 쓰기 중 파일 ingest + dotfile 잔해

### 배경 (실증)
- macOS `screencapture`는 `~/Desktop/.Name.png` (dotfile)을 먼저 쓰고 완성 후 이름을 바꾼다.
- `DirectoryWatcher`는 `.write` 이벤트 즉시 발화 → ingest가 **불완전 파일/이름 변경 전 파일**을 처리.
- 결과: (a) Vision이 이미지 로드 실패 → `try?`로 삼킴 → `ocr_text` 0인 행 영구 잔류,
  (b) dotfile 자체가 DB에 별도 행으로 등록(EVAL에서 `.RealCapture-...` 행 2건 관찰).

### 결정 — 3계층 방어
1. **dotfile 무시**: `DirectoryWatcher.filteredNames`에서 점두 파일(`.` prefix) 제외.
   macOS 임시 캡처 파일 관례(점두 + 완성 후 rename) 대응.
2. **안정화 대기(settle)**: ingest 전 파일 크기가 안정될 때까지 짧게 재검사
   (0.35s 간격 × 최대 4회, 크기 불변 시 통과). 쓰기 중 파일 재현 방지.
3. **OCR 실패 가시화**: `DefaultIntakePipeline.ingest`에서 OCR `try?` 제거 —
   실패 시 `ocrStatus`를 `.failed`로 기록(행 유지, 원인 추적 가능). OCR은 여전히 best-effort
   (캡처 아이템 손실 금지 원칙 유지)하되 **침묵하지 않는다**.

### 기각한 대안
- FSEvents `FSEventStreamCreateFlag` 시맨틱 의존 — 현재 dispatch 소스 방식과 불일치, 커널 버전별 차이.
- rename-only 감시(rename 이벤트만 ingest) — dispatch 소스는 이벤트 종류 구분 불가(`.write`만).

## 테스트 전략
- `filteredNames` dotfile 제외 단위 테스트 (기존 newFiles 테스트 확장)
- ShelfModelSettingsTests: `applyShelfSettings`가 settings 갱신 + 재스케줄 + autoStow=false 시
  스케줄 취소 확인
- IntakePipeline: OCR 실패 시에도 행 저장 + failed 마킹 확인 (stub OCRService 실패 주입)

## 결과
Sprint 13 구현으로 확정 예정. EVAL은 스프린트 외 발견 재현 시나리오(설정 변경 반영,
스크린샷 캡처 후 ocr_text ≥1)로 검증.
