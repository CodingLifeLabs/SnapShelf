# SnapShelf — Information Architecture

> 앱 표면(surfaces) 구조와 내비게이션 모델.

## 1. 표면(Surfaces)

```
Menu Bar Status Item (항상)
├─ 클릭 → ShelfPanel (주 표면)
│   ├─ 상단: SearchBar (⌘F)
│   ├─ 중앙: Shelf 스택 (최근 항목)
│   └─ 하단: 히스토리 단위 토글(10/50/100/∞) · ⚙ 설정
│
├─ 더블클릭 / ⌘O → LibraryWindow (탐색 표면)
│   ├─ 사이드바: Smart Folders(앱/도메인/프로젝트) · Collections · AI Folders
│   ├─ 메인: 그리드/리스트 뷰 토글
│   └─ 탭: Library · Timeline · Search ·(설정 시) Dev
│
└─ SettingsWindow (⌘,)
    ├─ General: 시작동작, 히스토리 한도, Shelf 호버 시간
    ├─ Capture & Folders: 감시 폴더, Smart Folder 규칙, 이름변경
    ├─ OCR & Search: 인덱스 상태, 재색인
    ├─ AI: provider(온디바이스/OpenAI/Claude/Gemini/Ollama), 키(Keychain)
    ├─ Privacy: 데이터 위치, 클라우드 전송 내역, 초기화
    └─ Advanced: Auto Cleanup 일수, 중복 임계값, 단축키
```

## 2. 내비게이션 모델

- **상주(Always-on)**: 메뉴바 아이템. 모든 표면의 진입점.
- **ShelfPanel(모달 패널)**: 비활성화 액티베이션(`.nonactivatingPanel`). 타 앱을 떠나지 않고 즉시 접근. ESC/외부 클릭으로 소멸.
- **LibraryWindow(표준 창)**: 포커스 이동. 탭 + 사이드바 마스터-디테일.
- **키보드 우선**: ⌘F 검색, ⌘1~4 탭, ↑↓ 선택, ⌘C 복사, 스페이스 미리보기(Quick Look).

## 3. 정보 구조 (데이터 → 뷰)

```
ShelfItem (핵심 엔티티)
├─ 정체성: id, sourceURL, createdAt, capturedAt
├─ 출처: appName, windowTitle?, browserURL?(Browser Detection)
├─ 콘텐츠: ocrText, summary?, suggestedName?, tags[]
├─ 분류: category, collectionId?, folderRuleId?
└─ 상태: isPinned, isDeleted, deletedAt?

조회 패턴(뷰별):
- ShelfPanel   → recent(N) + search(query)
- Library      → byFolder(rule) + filter/sort
- Timeline     → group(by: hour) order(asc)
- Collections  → where collectionId == x
- Search       → FTS5 match(ocrText|tags|appName)
```

## 4. 권한(TCC) 매핑

| 기능 | 권한 | 시점 |
|------|------|------|
| 폴더 감시 | Desktop/Pictures/Downloads 접근 | 온보딩 |
| 주문 캡처 | 화면 녹화(ScreenCaptureKit) | 캡처 액션 시 |
| 활성 창/URL | 접근성(일부) / AppleScript(브라우저) | URL 감지 시 |
| AI(클라우드) | 네트워크 + 사용자 키 | 옵트인 시 |

## 5. 메뉴바 메뉴(트레이)

```
SnapShelf ▾
├─ Open Shelf         ⌘⇧S
├─ New Capture        ⌘⇧5 (시스템 연계)
├─ Search             ⌘⇧F
├─ ─────────
├─ Library…
├─ Settings…          ⌘,
├─ ─────────
└─ Quit               ⌘Q
```
