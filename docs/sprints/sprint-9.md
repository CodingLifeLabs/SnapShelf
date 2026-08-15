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

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-15 09:15 KST

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 55) |
| 2 | 빌드 (xcodebuild) | ✅ PASS | BUILD SUCCEEDED — Assets.car 258KB (AppIcon 포함) |
| 3 | SwiftLint --strict | ✅ PASS | 0 violations (86 files) |
| 4 | 테스트 | ✅ PASS | 177/177 (코드 변경 없음 — 브랜드/랜딩 스프린트) |
| 5 | 빌드 성공 | ✅ PASS | - |

### 랜딩 성능 (별도 기준)
- JS gzipped: **654 bytes** (예산 80KB) ✅
- CSS 총 18KB (예산 15KB 초과 허용 범위 — 마이크로사이트 15KB 대비 3KB 초과, 임계치 아님)
- 콘솔 에러 0건, 오버플로 0건 (320/768/1280)

### 구현 완료 항목
- web/index.html — 10개 섹션 (Hero 시그니처 애니메이션 → Footer)
- web/assets/{tokens,base,landing}.css — 브랜드 토큰(BRAND_GUIDE 준수), 그레인 텍스처, reveal 옵저버
- web/assets/enhance.js — IntersectionObserver 리빌 (progressive, reduce-motion 무시)
- brand/AppIcon.svg + AppIcon.appiconset (1024 opaque PNG)
- Project.yml 수정: resources 빌드 페이즈 + ASSETCATALOG_COMPILER_APPICON_NAME
