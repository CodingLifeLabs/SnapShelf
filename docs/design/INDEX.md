# ADR 카탈로그 (Architecture Decision Records)

> 각 주요 결정을 ADR 로 기록. 상태: Proposed / Accepted / Superseded.
> 새 ADR 는 다음 번호 채번. 본문은 `docs/design/adr-NNNN-*.md` (필요시 분리).

## Accepted

| ADR | 제목 | 상태 | 요약 |
|-----|------|------|------|
| ADR-0001 | 네이티브 Swift/SwiftUI 채택 | Accepted | Electron/Tauri 대신 네이티브. 캡처/Vision/메뉴바/드래그 통합 품질 최고. harness 게이트는 네이티브용으로 적응(xcodebuild/XCTest). Intel+AS, macOS 14+. |
| ADR-0002 | 6개 static-framework 레이어 모듈 | Accepted | Types→Config→Repo→Service→Runtime→UI 각각 독립 프레임워크. 역방향 import = 컴파일 에러 + Gate1 린터 이중 차단. |
| ADR-0003 | FSEvents 스크린샷 폴더 감시 | Accepted | ⌘⇧4 시스템 단축키를 직접 후킹하지 않고 결과 파일을 감시. 가장 견고(Sukurini 동일 방식). TCC 권한 안내로 보완. |
| ADR-0004 | Vision OCR (오프라인) | Accepted | `VNRecognizeTextRequest`. 무료·오프라인·고정밀. 클라우드 의존 0 = 프라이버시 기본 충족. |
| ADR-0005 | SQLite + FTS5 검색 | Accepted | 시스템 sqlite(FTS5 포함). 100K 장 ≤150ms. 메타 + OCR 텍스트 색인. |
| ADR-0006 | AI provider 추상화 | Accepted | `AIService` 프로토콜. Foundation Models(온디바이스) 우선 + OpenAI/Claude/Gemini/Ollama. 옵트인, 키 Keychain. |
| ADR-0007 | LSUIElement accessory + NSPanel Shelf | Accepted | Dock 없는 메뉴바 앱. Shelf 는 `.nonactivatingPanel`(포커스 탈취 없음) — 핵심 UX. |

## Proposed (결정 보류 — 해당 Sprint 에서 확정)

| ADR | 제목 | 상태 | 검토 시점 | 결정 기준 |
|-----|------|------|-----------|-----------|
| ADR-0008 | GRDB.swift vs 시스템 SQLite3 | Proposed | Sprint 3 | 쿼리 편의성/의존성 비용. 시스템 sqlite3 로 시작, 복잡도 증가 시 GRDB. |
| ADR-0009 | 임베딩 기반 벡터 검색 도입 | Proposed | Sprint 6 / v2 | FTS5+LLM 재랭킹(v1) 대비 품질/비용. sqlite-vec 또는 로컬 ONNX. |
| ADR-0010 | 공증/배포 파이프라인 | Proposed | Sprint 10 | notarytool 자동화 여부, 키체인 자격증명 관리. 사용자 확인 필수. |

## Superseded
(없음)
