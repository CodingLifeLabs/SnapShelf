# SnapShelf — 프로젝트 가이드

> 이 파일은 SnapShelf 전용 가이드다. 범용 규칙은 상위 `~/.claude/CLAUDE.md` + harness-workflow 스킬을 따른다.
> 충돌 시: 이 파일(프로젝트 특화) > harness-workflow > 범용 규칙.

## 한 줄 소개

**SnapShelf** — The fastest way to capture, organize and rediscover your screenshots.
Sukurini(Shelf) + CleanShot X(OCR/캡처) + Raycast(검색/런처) + AI Screenshot Manager 의 결합.

## 기술 스택 (확정)

- Native **Swift 6.2 / SwiftUI + AppKit**, macOS 14.0+
- Capture: ScreenCaptureKit + FSEvents(스크린샷 폴더 감시)
- OCR: Vision `VNRecognizeTextRequest`
- Search: SQLite + FTS5
- AI: Foundation Models(on-device) + cloud providers + Ollama (provider 추상화)

## 아키텍처

```
Types → Config → Repo → Service → Runtime → UI(App)
```
각 레이어 = 독립 static framework(Project.yml). 역방향 import = 컴파일 에러.
상세: `docs/architecture.md`

## 작업 명령

```bash
# 프로젝트 재생성(Project.yml 변경 시)
npm run gen:project            # == xcodegen generate

# Gate 1: 레이어 의존성
npm run harness:lint

# Gate 2/5: 빌드
xcodebuild -project SnapShelf.xcodeproj -scheme SnapShelf -configuration Debug build

# Gate 3: SwiftLint
swiftlint lint --strict

# Gate 4: 테스트 + 커버리지
xcodebuild -project SnapShelf.xcodeproj -scheme SnapShelf \
  -configuration Debug test -enableCodeCoverage YES

# 실행 (EVAL)
open build/Debug/SnapShelf.app   # 경로는 DerivedData/Debug 일 수 있음
```

## 절대 규칙 (프로젝트 특화)

- `src/` 수정 시 반드시 `npm run gen:project` 로 프로젝트 동기화(새 파일 추가 시)
- `import SnapShelf*` 는 하위 레이어만 허용 (Gate 1 + 컴파일러 이중 차단)
- 강제 언래핑(`!`)/강제 캐스팅(`as!`)/`try!` 금지 (`.swiftlint.yml` error)
- `any`/`unknown` 에 해당하는 Swift 안티패턴: `Any`/`AnyObject` 무분별 사용 금지 → 명시적 타입
- 권한(TCC): 스크린샷 폴더/Desktop 접근은 Info.plist usage description 필수

## 현재 진행

- Phase 0 Bootstrap ✅ → Phase 1 PLANNER → Sprint 1
- 진행 상황: `docs/sprints/`, `ROADMAP.md`, `CHANGELOG.md`

## 응답 언어

대화: 한국어 / 코드·주석·커밋: 영어 / 문서(docs/): 한국어(코드 예시만 영어)
