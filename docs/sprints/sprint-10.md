# Sprint 10: 폴리시/애니메이션/공증 배포

## 구현 범위
- 애니메이션 튜닝(ANIMATION_SPEC.md): 시그니처/호버/소멸/드래그/패널/검색/타임라인/배지
- 접근성 최종: VoiceOver 라벨 전 항목, 키보드 전용, reduce-motion/대비
- Hardened Runtime + 권한 최소화 점검
- 공증(Notarization): `xcrun notarytool submit`(사용자 Apple ID) + 스테이플(`stapler staple`)
- DMG 패키징 + 체크섬 + 랜딩 다운로드 링크
- ADR: 공증/배포 전략

### 산출물
- 공증된 `SnapShelf-x.y.z.dmg`
- 릴리즈 노트(CHANGELOG.md 최종)

## GENERATOR가 완료해야 할 것
- [ ] Gate 1~5 + EVAL 전 PASS
- [ ] Hardened Runtime 검증
- [ ] 공증/스테이플 성공(사용자 자격증명 필요 → 확인 게이트)

## EVALUATOR가 검증할 것
- [ ] 릴리즈 빌드 정상 실행(클린 환경)
- [ ] 공증 상태(`spctl --assess`) 정상
- [ ] 전 기능 스모크 테스트
- [ ] 통과 기준: "배포 가능한 공증 .dmg 산출"

## 의존 Sprint
이전: Sprint 9 (전체 선행)
## 비고
- 공증/사이닝은 **사용자 확인 필수**(CLAUDE.md 행동 원칙). 자격증명 준비 전 자동 진행 금지.

## GENERATOR 자가 검증 결과
실행 일시: 2026-08-15 09:35 KST

| Gate | 항목 | 결과 | 비고 |
|------|------|------|------|
| 1 | 레이어 의존성 | ✅ PASS | 위반 0건 (파일 55) |
| 2 | 빌드 (Debug + Release) | ✅ PASS | Release: ad-hoc + Hardened Runtime (`flags=0x10002(adhoc,runtime)`), `codesign --verify --deep --strict` 통과 |
| 3 | SwiftLint --strict | ✅ PASS | 0 violations (86 files) |
| 4 | 테스트 | ✅ PASS | 177/177 |
| 5 | 빌드 성공 | ✅ PASS | DMG 산출: build/SnapShelf-0.1.0.dmg (2.1MB, SHA-256 92326e6d…) |

### 구현 완료 항목
- ANIMATION_SPEC 반영: 드래그 리프트(§4 scale 1.04 + shadow + spring 복귀), 검색 결과 순차 등장(§6 12ms stagger), reduce-motion 전 경로 유지
- 접근성: 아이콘 전용 버튼(Share/toolbar) 명시적 accessibilityLabel 추가 — 기존 .help() 병행
- Project.yml: Debug(무서명)/Release(ad-hoc+Hardened Runtime) 구성 분리
- DMG 패키징(UDZO + Applications 심볼릭 링크) + SHA-256 체크섬
- ADR-0010 공증/배포 전략 문서화 (docs/design/adr-0010-notarization-deploy.md)

### 사용자 확인 필요 (공증 게이트)
- Developer ID 인증서 + App Store Connect API 키(또는 Apple ID) 준비 후:
  1. Developer ID 서명 → 2. notarytool submit → 3. stapler staple → 4. spctl 검증
- 준비되면 알려달라. 그 전까지는 ad-hoc 서명 DMG(팀 내 테스트용)로 유지.
