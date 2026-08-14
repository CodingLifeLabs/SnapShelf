# SnapShelf — Animation Spec

> 원칙: compositor-friendly 속성만(`opacity`, `transform`, `clipShape`).
> 이징: expo-out `cubicBezier(0.16, 1, 0.3, 1)`, 시스템 `.spring(0.4, 0.8)`.
> Reduce Motion: 모두 즉시/페이드 전환.

## 1. 캡처 → Shelf 등장 (시그니처)

```
trigger:  FSEvents 새 파일 감지
from:     화면 우하단 외곽(offset +40,+40, scale 0.6, opacity 0)
to:       Shelf 스택 최상단(slide-up + scale 1.0, opacity 1)
duration: 220ms
easing:   spring(response:0.34, dampingFraction:0.82)
extras:
  - 진입 시 accent-warm 1px 링 → 600ms 후 페이드아웃
  - 기존 스택 항목: y += itemHeight (spring, 200ms) — 부드러운 밀어내기
reduce-motion: opacity 0→1 즉시(fade 120ms), transform 생략
```

## 2. ShelfItem 호버 툴바

```
from:  opacity 0, y +6
to:    opacity 1, y 0
duration: 120ms
easing: expo-out
reduce-motion: 즉시 표시
```

## 3. ShelfItem 소멸(히스토리로)

```
from:   scale 1.0, opacity 1, 현재 위치
to:     scale 0.85, opacity 0, 하단 스택으로 슬라이드
duration: 180ms
reduce-motion: fade 100ms
```

## 4. 드래그 시작

```
from:  scale 1.0
to:    scale 1.04 + shadow(--elev-2) + accent 링
duration: 140ms spring
드롭 후: 원복(spring 220ms) 또는 제거(소멸 애니메이션)
```

## 5. 패널 열기/닫기

```
open:  opacity 0→1 + scale 0.96→1.0 + y +8→0   (200ms, expo-out)
close: 역방향 (160ms)
reduce-motion: fade only
```

## 6. 검색 결과 갱신

```
- 결과 항목: 순차적(opacity+slide, 12ms stagger, 총 ≤180ms)
- 스켈레톤→이미지 교체: opacity crossfade 120ms
- 스니펫 하이라이트: accent 배경 clipShape 확장(160ms)
```

## 7. Smart Folder 자동 이동(라이브러리)

```
- Library 사이드바: 새 폴더 등장 slide-in(180ms) + 카운트 배지 pop(spring)
- 항목이 폴더로 "떨어지는" 표현: 위계 변화 없이 배지 카운트 증가 + 마이크로 pulse
reduce-motion: 즉시 반영
```

## 8. 타임라인 스크럽

```
- 스크럽 핸들: x 위치 추종(.interactiveSpring)
- 해당 그룹: accent 테두리 spring(220ms) + 나머지 dim(opacity 0.5, 160ms)
```

## 9. 메뉴바 배지

```
- 새 항목: 카운트 숫자 flip(3D rotateY, 200ms) + 링 pulse(1 사이클, 600ms)
- idle 복귀: fade
```

## 10. 타이밍 토큰

```
--t-instant: 120ms   (호버, 칩)
--t-quick:   180ms   (소멸, 결과)
--t-base:    220ms   (등장, 패널)
--t-emph:    320ms   (강조 전환, 드물게)
--ease-expo: cubic-bezier(0.16, 1, 0.3, 0.1)
```

## 11. 성능 가드

- will-change 없이도 compositor-friendly 유지(`.transform`/`.opacity`).
- 동시 다중 애니메이션(버스트 캡처)은 큐+디바운스로 60fps 보장.
- 레이아웃 바운드(width/height/top) 애니메이션 금지.
