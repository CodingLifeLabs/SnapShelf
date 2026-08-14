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
