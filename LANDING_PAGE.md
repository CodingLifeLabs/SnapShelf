# SnapShelf — Landing Page Spec

> 별도 웹 프로젝트(`web/`). 정적 사이트. 방향: **에디토리얼 + Swiss 정밀 + 네이티브 머티리얼**.
> 범용 규칙: `~/.claude/rules/web/*`(Anti-Template, 성능, 접근성) 준수.

## 1. 구조(섹션)

```
1. Hero            — 시그니처 애니메이션(캡처→Shelf→정리), 헤드라인, CTA(Download) + macOS 벳지
2. Problem/Agitate — "분명 찍었는데 못 찾겠다" — 일러스트 + 숫자(바탕화면 스크린샷 수)
3. Core Loop       — Capture → Shelf → AI → Organize → Search → Archive (수평 스크롤/스크롤리텔링)
4. Features 그리드  — 비대칭 벤토(bento), 균일 카드 금지
5. 비교표           — BRAND_GUIDE.md 표
6. GIF/롤플레이     — 실제 동작(Shelf 등장, 드래그, 검색, 자동 정리)
7. Privacy         — "오프라인 우선. AI 는 당신이 켤 때만." 강조
8. FAQ             — 권한/오프라인/AI/가격/지원기기
9. Pricing         — 단순(무료 베타 / Pro). 과잉 티어 금지
10. Footer + Download(Notarized .dmg)
```

## 2. Hero 시그니처 애니메이션(웹)

```
Take Screenshot → 파일 떨어짐 → Shelf 로 빨려듦 → AI → Folder → Done
- GSAP ScrollTrigger 또는 CSS scroll-driven animations.
- compositor-friendly(transform/opacity/clip-path) 만.
- prefers-reduced-motion: 정적 스토리보드로 전환.
```

## 3. 비주얼 디렉션(웹)

- **배경**: 다크 잉크 `#0F1015` 기저 + 종이 카드 `#FBFBFD` 대비(에디토리얼 라이트/다크).
- **타이포**: Fraunces(디스플레이 세리프, 캐릭터) + Inter/Söhne(본문). 시스템 폴백.
- **레이아웃**: 비대칭 그리드, 규칙적 여백 아님, 그리드-브레이킹 벤토.
- **악센트**: indigo `#6E56CF` + amber `#E8A33D`(제한).
- **질감**: 미세 그레인/노이즈(저렴한 그라데이션 블롭 금지).

## 4. 성능(CWV)

- LCP <2.5s, INP <200ms, CLS <0.1, FCP <1.5s, TBT <200ms.
- JS gzipped ≤80kb(마이크로사이트). 정적/SSG. 히어로 영상/이미지 lazy + AVIF/WebP.
- 폰트 2 family, `font-display: swap`, 프리로드 1 weight.

## 5. 기술(웹)

- 정적 사이트(Astro 또는 Next.js static export) — 경량 우선.
- 인라인 크리티컬 CSS. 히어로 미디어만 preload.
- 접근성: 시맨틱 HTML, 키보드, 대비 AA+, alt.

## 6. 다운로드/CTA

- "Download for macOS"(Notarized .dmg) + 버전 + 파일크기 + 체크섬.
- 이메일 수집(베타) — 선택, 스팸 아님.
- GitHub 링크(오픈소스 일부/이슈).

## 7. SEO/메타

- title/description/OG/Twitter 카드. 구조화 데이터(SoftwareApplication).
- sitemap/robots. 단일 페이지라도 canonical.

> 구현은 Sprint 9. 본 문서는 명세. 코드는 `web/` 하위 별도 프로젝트.
