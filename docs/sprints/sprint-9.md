# Sprint 9: 랜딩 + 브랜드

## 구현 범위
- `web/` 정적 사이트(LANDING_PAGE.md): Hero 시그니처 애니메이션, Core Loop 스크롤리텔링, 벤토 Features, 비교표, GIF/롤플레이, Privacy, FAQ, Pricing, Download
- AppIcon/로고 확정(BRAND_GUIDE.md): SVG + macOS AppIcon.appiconset(1024 + 파생)
- 일관된 토큰(컬러/타이포/모션) — 앱↔랜딼 정합
- CWV(LCP<2.5/INP<200/CLS<0.1), 접근성 AA+, SEO/OG

### 산출물
- `web/` (정적 사이트 — Astro/Next static export)
- `App/Resources/Assets.xcassets/AppIcon.appiconset/*`
- `docs/BRAND_GUIDE.md` 최종화

## GENERATOR가 완료해야 할 것
- [ ] 랜딩 빌드 성공 + CWV/번들예산 준수(JS gz ≤80kb)
- [ ] 접근성/대비/시맨틱 점검
- [ ] AppIcon 에셋 정상 적용(`xcodebuild build`)

## EVALUATOR가 검증할 것
- [ ] 랜딩 각 섹션 렌더 + Hero 애니메이션
- [ ] reduce-motion 대체 정상
- [ ] 반응형(320/768/1024/1440) 오버플로 없음
- [ ] 앱 아이콘 표시
- [ ] 통과 기준: "템플릿 느낌 없는 랜딩 + 브랜드 일관성"

## 의존 Sprint
이전: Sprint 8 (제품 기능 확정 후 랜딩)
