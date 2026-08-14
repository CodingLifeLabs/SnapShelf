# SnapShelf 배포 체크리스트 (초안)

> 모든 Sprint 완료 후 실행. **배포·코드사이닝·공증은 사용자 확인 필수** (CLAUDE.md 행동 원칙).

## 로컬 릴리즈 빌드

```bash
xcodebuild -project SnapShelf.xcodeproj -scheme SnapShelf \
  -configuration Release build \
  CONFIGURATION_BUILD_DIR=build/Release
```

## 배포 전 체크리스트

- [ ] Gate 1~5 + EVALUATOR 전체 PASS
- [ ] `CHANGELOG.md` 버전 갱신(MARKETING_VERSION)
- [ ] 앱 아이콘(AppIcon) 확정 — BRAND_GUIDE.md
- [ ] Info.plist 버전·usage description 최종 검토
- [ ] Hardened Runtime + 권한 최소화
- [ ] 공증(Notarization): `xcrun notarytool submit` — 사용자 Apple ID 필요
- [ ] 스테이플링: `xcrun stapler staple`
- [ ] DMG/ZIP 패키징
- [ ] 랜딩 페이지(web/) 다운로드 링크 연결

## 외부 API (AI providers)

- 키는 `.env` / Keychain. 소스에 하드코딩 금지.
- 배포 빌드에 키 포함 금지 — 사용자가 설정에서 입력.
