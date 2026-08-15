# ADR-0010: 공증/배포 파이프라인

- **상태**: Accepted (Sprint 10)
- **결정일**: 2026-08-15

## 배경

SnapShelf beta(0.1.0)를 배포 가능한 산출물로 만들어야 한다. 사용자가 Gatekeeper
경고 없이 .dmg를 열려면 Developer ID 서명 + Apple 공증(notarization) + 스테이플링이
필요하다. 단, 공증은 사용자 Apple ID 자격증명을 소비하므로 CLAUDE.md 행동 원칙상
사용자 확인 없이 자동 실행할 수 없다.

## 결정

1. **빌드 구성 분리** (Project.yml configs)
   - Debug: 부호 없음(빠른 로컬 반복, 기존 스프린트와 동일)
   - Release: ad-hoc 서명 + **Hardened Runtime** (`flags=runtime`) — 공증 전 단계 요건 충족
2. **배포 물품**: `SnapShelf-{version}.dmg` (UDZO, Applications 심볼릭 링크 포함) + SHA-256 체크섬
3. **공증 절차** (사용자 확인 후 수동/반자동 실행):
   ```
   # 1) Developer ID 서명 (사용자 인증서 — 확인 필요)
   codesign --deep --force --options runtime --timestamp \
     --sign "Developer ID Application: <이름> (<TEAMID>)" SnapShelf.app
   # 2) zip 후 공증 제출 (App Store Connect API 키 또는 Apple ID — 확인 필요)
   xcrun notarytool submit SnapShelf.zip --keychain-profile SnapShelf --wait
   # 3) 스테이플
   xcrun stapler staple SnapShelf.app
   # 4) 검증
   spctl --assess --verbose=4 SnapShelf.app
   ```
4. **자동화 범위**: 서명/DMG/체크섬까지는 자동. 공증 제출은 사용자 승인 게이트 이후.

## 근거

- Hardened Runtime은 공증 필수 요건이며 Vision/SQLite 등 사용 API에 엔타이틀먼트 추가 불필요(순수 라이브러리 링크만 사용).
- ad-hoc 서명 Release 빌드는 공증 전 검증(팀 내 배포, 로컬 spctl 확인)에 사용.
- 인증서·자격증명은 키체인 프로필로 관리 — 저장소에 절대 커밋하지 않음.

## 결과

- ✅ Release 빌드: `flags=0x10002(adhoc,runtime)` 확인, `codesign --verify --deep --strict` 통과
- ✅ DMG 2.1MB + SHA-256 생성 (`build/SnapShelf-0.1.0.dmg`)
- ⏳ Developer ID 서명 + 공증: 사용자 자격증명 준비 시 실행 (사용자 확인 게이트)
