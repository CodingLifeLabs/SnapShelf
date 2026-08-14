# SnapShelf — Apple HIG 준수 가이드

> Apple Human Interface Guidelines(macOS) 기반. 본 앱은 **메뉴바 액세서리(LSUIElement)** 이며
> Shelf 는 비모달 패널. 사용자가 "네이티브처럼" 느끼도록 한다.

## 1. 앱 모델

- **Accessory(LSUIElement)**: Dock/메인 메뉴바 없음. `NSStatusItem` 로 상주.
- Shelf = `NSPanel` with `.nonactivatingPanel` → 호출 앱의 포커스를 빼앗지 않음(핵심).
- 라이브러리/설정 = 표준 `NSWindow`(포커스 이동 허용).

## 2. 머티리얼 & 비브랜시

- Shelf 패널: `vibrancy = .titlebar` / `.hud`, `blendingMode = .behindWindow`, `appearance = .aqua/vibrant`.
- SwiftUI: `.background(.ultraThinMaterial)`. 시스템 다크/라이트 자동.
- 불투명한 회색 박스로 "네이티브감" 훼손 금지.

## 3. 타이포그래피

- **SF Pro(시스템) 강제**. 커스텀 폰트 앱 내 사용 금지(다국어/다이내믹 타입/Dynamic Type 깨짐).
- 시스템 텍스트 스타일(`.headline`, `.body`, `.caption`) 사용 → 접근성 스케일 자동 대응.

## 4. 색상

- 시스템 시맨틱(`NSColor.labelColor`, `.secondaryLabelColor`, `.controlBackgroundColor`) 우선.
- 브랜드 악센트는 `AccentColor` 에셋 하나만. 상태색은 시스템(`systemBlue/Red/Green/Orange`).

## 5. 컨트롤 & 인터랙션

- 네이티브 컨트롤 우선(Button, Toggle, Menu, Toolbar). 커스텀 위젯은 의도가 있을 때만.
- **키보드 전용 조작 가능**: 탭 이동, ⌘F, ↑↓, Enter, ESC. 포커스 링 표시.
- 드래그: `NSItemProvider` 로 파일/PNG/URL 제공 → Finder/Slack/Discord/ChatGPT 로 자연 드롭.
- 트랙패드: Force Touch(미리보기), 2손가락(줌/스와이프) 지원.

## 6. 애니메이션

- 시스템 스프링/이징 사용(`NSAnimationContext`, SwiftUI `.spring`).
- **Reduce Motion**: `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion` 감지 → 즉시 전환(페이드만).

## 7. 접근성

- 모든 인터랙티브 요소에 `accessibilityLabel`/`accessibilityHint`/`accessibilityValue`.
- Shelf 항목: "스크린샷, {앱}, {시간}, OCR 요약 {n}자".
- 충분한 터치/클릭 타깃(≥24pt). 대비 4.5:1 이상(텍스트).
- VoiceOver: 검색결과를 라이브 영역으로 발표.

## 8. 표준 메뉴/단축키

- 시스템 단축키 침범 금지(⌘⇧4 는 시스템 스크린샷 — 우리는 그 결과를 감시).
- ⌘W 패널 닫기, ⌘, 설정, ⌘Q 종료, ⌘F 검색.

## 9. 알림/피드백

- 권한 요청은 명확한 사전 맥락 후에(`request when needed`). 블라인드 프롬프트 금지.
- 성공/실패는 침묵보다 미세한 피드백(배지/토스트). 과도한 모달 경고 금지.
- 진행(OCR/색인)은 progress 표시 + 취소 가능.

## 10. 보안/프라이버시 (HIG Privacy)

- 데이터 수집 최소화. AI 옵트인 명확. 클라우드 전송 시 항목 표시.
- 권한 안내 카드는 "왜 필요한가" 를 사용자 언어로.

## 참고

- [macOS HIG](https://developer.apple.com/design/human-interface-guidelines/macos) · [AppKit Panels](https://developer.apple.com/documentation/appkit/nspanel)
