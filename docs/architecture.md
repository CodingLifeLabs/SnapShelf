# SnapShelf 아키텍처

> 단방향 레이어 구조. 역방향 import는 **컴파일러(XcodeGen static framework)** 와
> **Gate 1 린터(`.harness/linters/dependency-direction.js`)** 가 이중으로 차단한다.

---

## 레이어 (위→아래 단방향)

```
Types → Config → Repo → Service → Runtime → UI(App)
```

각 레이어는 **독립 static framework 모듈**이다(Project.yml).
상위 레이어는 하위 레이어만 import 할 수 있다. 역방향 import는 컴파일 에러.

| 레이어 | 모듈명 | 경로 | 역할 | 허용 import |
|--------|--------|------|------|-------------|
| 1 Types | `SnapShelfTypes` | `src/Types` | 순수 도메인 모델·enum·값 타입. 프레임워크 의존성 없음 | (없음) |
| 2 Config | `SnapShelfConfig` | `src/Config` | 환경변수·경로·상수·설정 스키마 | Types |
| 3 Repo | `SnapShelfRepo` | `src/Repo` | 영속성·데이터 접근(SQLite/GRDB, FTS5), 파일 시스템 I/O | Types, Config |
| 4 Service | `SnapShelfService` | `src/Service` | 비즈니스 로직(OCR, AI, 분류, 이름변경, 중복탐지, 정리 규칙) | Types, Config, Repo |
| 5 Runtime | `SnapShelfRuntime` | `src/Runtime` | 앱 라이프사이클, 메뉴바, NSPanel, 파일 감시(FSEvents), 권한(TCC), 핫키 | Types, Config, Repo, Service |
| 6 UI | `SnapShelf`(app) | `App/Sources` | SwiftUI 뷰, App 진입점, Shelf 패널 | 전체 |

> "UI(App)"는 가상 레이어명 `SnapShelfUI`로 취급. Gate 1 린터는 `App/Sources`를 이 이름에 매핑한다.

---

## 의존성 역전 규칙

하위 레이어가 상위를 알아야 하는 경우(예: Repo가 Service의 분류 결과를 받아야 함)는
**상위가 하위에 protocol을 주입**하는 방식으로 해결한다. 하위 → 상위 직접 import는 금지.

- ✅ `Service`가 `Repo`의 protocol을 호출
- ✅ `Repo`에 `ClassifierProtocol`을 `Service`가 정의하여 주입 가능(단 protocol 선언은 Types에 둘 수도 있음)
- ❌ `Repo`가 `import SnapShelfService`

---

## 기술 스택 (확정)

- **언어/UI**: Swift 6.2 / SwiftUI + AppKit (macOS 14.0 Sonoma+)
- **화면 캡처**: `ScreenCaptureKit` (주문 캡처용) + FSEvents(스크린샷 폴더 감시)
- **OCR**: `Vision` `VNRecognizeTextRequest` (오프라인, 무료, 고정밀)
- **검색**: SQLite + **FTS5** (시스템 sqlite 포함). GRDB.swift 도입 검토(Sprint 3)
- **AI**: Foundation Models(온디바이스, macOS 26+) + 클라우드 API(OpenAI/Claude/Gemini) + Ollama(로컬) — provider 추상화
- **Shelf 표면**: `NSStatusBar` + `NSPanel`(always-on-top, `.nonactivatingPanel`)
- **드래그**: `NSItemProvider` / SwiftUI `.draggable` / `.onDrag`

---

## 데이터 흐름 (캡처 → Shelf → 정리)

```
1. 사용자 ⌘⇧4 → macOS 가 스크린샷을 ~/Pictures/Screenshots(또는 Desktop) 에 저장
2. Runtime: FSEvents 가 새 파일 감지 → 새 ShelfItem 생성
3. Runtime → Service: 후처리 파이프라인 예약(OCR·분류·이름변경)
4. Service: Vision OCR → Repo(FTS5 인덱스) / AI 분류 → Smart Folder 이동(Repo)
5. UI: ShelfItem 이 Shelf 패널에 애니메이션으로 진입
6. 사용자: 복사 / 드래그 / 공유 / OCR / AI 요약 / 핀
7. (30일 후) Service: Auto Cleanup → 휴지통
```

---

## 모듈·타깃 구조 (XcodeGen)

6개 static framework + 1 app + 1 통합 테스트 번들.
재생성: `npm run gen:project` (== `xcodegen generate`).

```
SnapShelfTypes   (framework, static)   ← src/Types
SnapShelfConfig  (framework, static)   ← src/Config          → Types
SnapShelfRepo    (framework, static)   ← src/Repo            → Types, Config
SnapShelfService (framework, static)   ← src/Service         → Types, Config, Repo
SnapShelfRuntime (framework, static)   ← src/Runtime         → Types, Config, Repo, Service
SnapShelf        (application)         ← App/Sources         → 전체
SnapShelfTests   (bundle.unit-test)    ← tests               → 전체
```

---

## 폴더 구조

```
snapshelf/
├── Project.yml              # XcodeGen 스펙
├── .swiftlint.yml           # Gate 3
├── package.json             # harness 스크립트(린터 등)
├── src/
│   ├── Types/ Config/ Repo/ Service/ Runtime/
├── App/
│   ├── Info.plist           # LSUIElement(accessory) + TCC 설명
│   ├── Sources/             # App 진입점 · SwiftUI
│   └── Resources/Assets.xcassets
├── tests/                   # 각 모듈 단위 테스트 (통합 번들)
├── .harness/
│   ├── linters/dependency-direction.js   # Gate 1
│   └── structural-tests/
├── docs/                    # 이 파일 + spec/sprints/design/*
└── web/                     # 랜딩 페이지(별도, Sprint 9)
```
