# Sprint 4: AI 이름변경/요약 (provider)

## 구현 범위
- `AIService` 프로토콜 + 구현체(AI_ARCHITECTURE.md):
  - `FoundationModelsAIService`(macOS 26+, 가용성 게이트)
  - `HTTPAIService`(OpenAI/Claude/Gemini 공용 REST, 사용자 키)
  - `OllamaAIService`(로컬 엔드포인트)
- 팩토리: `AIProviderConfig` → 구현체
- 기능: `rename`, `summarize`(3줄) — IntakePipeline 백그라운드 적용(옵트인 시)
- Keychain 키 저장, 옵트인 전 AI 메뉴 비활성(점선)
- 비용/속도 제어(큐, 캐시 content-hash), 규칙 폴백(앱 휴리스틱 이름)

### 파일(예상)
- `src/Service/AIService.swift`, `FoundationModelsAIService.swift`, `HTTPAIService.swift`, `OllamaAIService.swift`, `AIServiceFactory.swift`
- `src/Config/AIProviderConfig.swift`
- `src/Runtime/KeychainStore.swift`
- `tests/ServiceTests/*AIService*Tests.swift`(목 클라이언트)

## GENERATOR가 완료해야 할 것
- [ ] provider 추상화 + 목 기반 단위 테스트(실제 키 없이)
- [ ] 옵트인 게이트/규칙 폴백 테스트
- [ ] Gate 1~5 통과

## EVALUATOR가 검증할 것
- [ ] 미옵트인: AI 메뉴 비활성 + "AI 켜기" 유도
- [ ] 옵트인(가능 provider): 캡처 후 이름 제안/요약 표시
- [ ] 실패 시 원본 보존 + 안내
- [ ] 통과 기준: "옵트인 후 AI 이름변경/요약 동작, 미옵트인은 비활성"

## 의존 Sprint
이전: Sprint 3 (OCR 텍스트가 AI 입력)
