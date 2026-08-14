# SnapShelf — Design System

> 방향: **"Shelf Glass — Editorial Precision"**. 네이티브 macOS 머티리얼(유리/비브랜시)을
> 우선하되, 위계가 분명한 에디토리얼 타이포와 하나의 분명한 악센트로 템플릿 느낌을 배제한다.
> 범용 규칙: `~/.claude/rules/web/design-quality.md` (Anti-Template Policy) 준수.

## 1. 디자인 원칙

1. **머티리얼 우선(Material-first)**: Shelf 는 유리(`.ultraThinMaterial` + vibrancy). 불투명 회색 박스 금지.
2. **위계로 말하라**: 균일한 간격·균일한 강조 금지. 스케일 대비로 순서를 만든다.
3. **속도가 곧 미학**: 등장/소멸 ≤200ms. 동작은 흐름을 명확히(캡처→빨려듦→적재).
4. **오프라인 침착함**: 과도한 컬러/그라데이션 없음. 잉크 + 종이 + 단일 악센트.
5. **접근성 기본**: 대비 AA+, VoiceOver 라벨, reduce-motion 대체.

## 2. 컬러 토큰

> 앱 크롬은 **시스템 시맨틱 컬러**(`Label`, `secondaryLabel`, `controlBackground`...) 사용 —
> 라이트/다크 자동 대응(HIG 필수). 브랜드 악센트만 `AccentColor` 에셋으로 고정.

| 토큰 | 라이트 | 다크 | 용도 |
|------|--------|------|------|
| `--accent` | `#6E56CF` (indigo-violet) | `#8B72E0` | 액션·포커스·선택 |
| `--accent-warm` | `#E8A33D` (amber) | `#F0B65A` | "새 항목/활성" 강조(제한적) |
| `--ink` | `#14161C` | `#F5F6FA` | 본문 텍스트(= `.label`) |
| `--paper` | `#FBFBFD` | `#1C1D24` | 기저 표면 |
| `--surface-glass` | `.ultraThinMaterial` | 동일 | Shelf 패널 |
| `--hairline` | `#E4E6EC` | `#2A2C36` | 1px 구분선 |

> 악센트 oklch 근사: indigo `oklch(0.55 0.20 295)`, amber `oklch(0.78 0.14 70)`.

## 3. 타이포그래피 (앱)

SF Pro(시스템) — HIG 요구. **의도적 스케일 계층**:

| 역할 | 스타일 | size(weight) |
|------|-------|--------------|
| Shelf 항목 파일명 | `.headline` | ~15 / .semibold |
| 메타(앱·시간) | `.caption` | ~11 / .regular, secondary |
| 검색결과 스니펫 | `.callout` | ~13 / .regular |
| 빈 상태 헤드라인 | `.title2` | ~20 / .bold |
| 랜딩 히어로(웹) | display | `clamp(3rem, 1rem+7vw, 7rem)` — 별도 페어링(LANDING_PAGE.md) |

## 4. 간격·반경·고도

```
--r-card:   16px      (Shelf 항목, 패널)
--r-chip:   8px       (태그, 액션 칩)
--r-pill:   999px     (핀, 배지)
--space-1:  4   --space-2: 8   --space-3: 12   --space-4: 16   --space-6: 24   --space-8: 32
--elev-1:   y2 blur12 opacity8%    (Shelf 항목 호버)
--elev-2:   y8 blur24 opacity14%   (Shelf 패널)
```
균일 간격 금지 — 4/8 리듬 위에서 위계에 따라 건너뛰기(예: 헤더 24 → 바디 12).

## 5. 모션 원칙

- **compositor-friendly**: `opacity`, `transform(scale/translate/rotation)`, `clipShape` 만 애니메이트.
- **이징**: `cubicBezier(0.16, 1, 0.3, 1)` (expo-out). 시스템 `.spring(response:0.4, dampingFraction:0.8)`.
- **reduce-motion**: 애니메이션 → 즉시 전환(페이드만). `@Environment(\.accessibilityReduceMotion)`.
- 상세: `ANIMATION_SPEC.md`.

## 6. 핵심 컴포넌트 카탈로그

### C-01 ShelfItem
- 썸네일(가변 비율, 고정 높이 ~120) + 하단 메타 오버레이.
- 호버 시: `--elev-1` + 상단 툴바(복사/드래그 핸들/공유/OCR/AI/핀) 페이드인.
- 드래그 핸들 = 전체 항목(`.draggable` via `NSItemProvider`).
- 새 항목: `accent-warm` 1px 링 0.6s 후 소거.

### C-02 ShelfPanel
- 우하단 고정 `NSPanel`(`.nonactivatingPanel`, always-on-top). 폭 ~320, 가변 높이(최대 6 항목).
- `--surface-glass` + `--r-card` + `--elev-2`. 상단 검색입력(⌘F 포커스).

### C-03 SearchBar / Results
- 상단 고정. 결과: 썸네일 + 파일명 + OCR 스니펣(하이라이트) + 메타.
- 빈 결과: 에디토리얼 일러스트 + "캡처를 시작하면 여기에 나타납니다".

### C-04 FolderRow (Library)
- 트리/사이드바. 드래그-드롭 수용. 카운트 배지(`--r-pill`, accent).

### C-05 TimelineTrack
- 가로/세로 시간축. 시간 라벨 + 항목 썸네일(앱 색상 점).
- 스크럽 시 해당 시점의 항목 하이라이트.

### C-06 AIChip
- AI 가공 표시(이름변경/요약/분류). 비활성(옵트인 전) = 점선 회색.

## 7. 라이트/다크

- 시스템 따름(기본). 둘 다 의도적이어야 함(design-quality.md).
- 다크: 유리 비브랜시 강조, 악센트 채도 +10%.
- 라이트: 종이 대비 선명, 악센트 동일.

## 8. 안티패턴 (금지)

- 균일 카드 그리드(위계 없음), 중앙 정렬 히어로+그라데이션 블롭, 단조 회색+장식 악센트 1개.
- 라이브러리 기본값을 "완성품"으로 포장.
- 레이아웃 바운드 속성(width/height/top) 애니메이션 — compositor-friendly 만.

## 9. 레퍼런스 무드

Sukurini(Shelf 물리감) · Raycast(키보드 중심 · 속도) · CleanShot X(캡처 정밀도) ·
Linear/Things3(에디토리얼 위계 + 침착한 악센트).
