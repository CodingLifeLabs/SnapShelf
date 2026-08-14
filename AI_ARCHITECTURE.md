# SnapShelf — AI Architecture

> provider 추상화. 기본 오프라인, AI 는 옵트인. Service 레이어 소유.

## 1. provider 모델

```swift
public protocol AIService: Sendable {
    func rename(_ item: ShelfItem, context: AIContext) async throws -> String
    func summarize(_ text: String) async throws -> String          // 3줄 요약
    func classify(_ item: ShelfItem) async throws -> ItemCategory
    func semanticSearch(query: String, candidates: [ShelfItem]) async throws -> [RankedItem]
}

public enum AIProvider: Sendable {
    case foundationModels      // 온디바이스(macOS 26+)
    case openAI(model: String)
    case claude(model: String)
    case gemini(model: String)
    case ollama(endpoint: URL, model: String)
}
```

구현체: `FoundationModelsAIService`, `HTTPAIService`(OpenAI/Claude/Gemini 공용 REST),
`OllamaAIService`. 팩토리가 `AIProviderConfig` → 구현체 생성.

## 2. 사용 시나리오

| 기능 | 입력 | 출력 | provider |
|------|------|------|----------|
| 이름변경 | OCR/메타/앱 | 제안 파일명 | 모두 |
| 요약 | OCR 텍스트 | 3줄 | 모두 |
| 분류 | OCR/메타/앱 | ItemCategory | 모두 |
| 컬렉션 | 항목 그룹 | 주제/그룹핑 | 모두 |
| 중복판단 | pHash + OCR | 보관본 선택 | (규칙 우선, AI 보조) |
| 의미검색 | 자연어 쿼리 | 랭킹 후보 | 모두 |

## 3. 온디바이스 우선

- **Foundation Models**(macOS 26+): 이름변경/요약/분류는 온디바이스로 충분. 프라이버시 최고.
- 가용성 게이트: `if #available(macOS 26, *)` → 사용, else 폴백(클라우드/Ollama).
- 본 호스트(macOS 15 / Intel): Foundation Models 미지원 → 클라우드/Ollama fallback 이 기본.

## 4. 클라우드/로컬 서버

- **OpenAI/Claude/Gemini**: REST, 사용자 API 키(Keychain). 엔드포인트 고정/설정.
- **Ollama**: 로컬 `http://localhost:11434`. 오프라인(기기 내) 이면서 무료.
- 모든 HTTP: 타임아웃, 재시도(지수백오프), 사용자 취소 가능.

## 5. 프라이버시·보안

- **옵트인 필수**: provider + 키 입력 전 AI 메뉴는 비활성(점선, "AI 켜기").
- 전송 최소화: 이미지 대신 OCR 텍스트/메타/스니펫 전송(v1). 이미지 필요 시 명시 동의.
- 키: Keychain 저장. 소스/로그 금지. `.env` 는 개발 전용(gitignored).
- 전송 내역: 설정 Privacy 에 표시(어떤 항목이 어떤 provider 로 갔는지).

## 6. 비용·속도 제어

- 큐 + 동시성 제한(기본 2).
- 이름변경/분류는 캡처 직후 백그라운드(사용자 대기 없음).
- 요약/의미검색은 사용자 액션 → 응답 ≤3s 타깃(진행 표시 + 취소).
- 캐시: 동일 입력 결과 재사용(content hash).

## 7. 실패·폴백

- provider 장애 → 규칙 기반 폴백(예: 분류 = 앱 휴리스틱).
- 원본 보존 원칙: AI 실패해도 항목/OCR/파일은 유지.
- 2회 연속 실패 → 사용자 알림(두 번째 물림에 지장 시 에스컬레이션).

## 8. 확장 포인트

- 새 provider 추가 = `AIService` 구현체 + 팩토리 분기. 레이어 규칙 준수(Service 내).
- 프롬프트 템플릿은 Config(상수) — 코드에 하드코딩 금지, 버전 관리.
