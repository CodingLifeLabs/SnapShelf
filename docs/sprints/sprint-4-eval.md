# Evaluator Report — Sprint 4

실행 일시: 2026-08-14
검증 대상: SnapShelf.app (Debug, + rule-based AI rename)

## 결과: PASS

## 검증 방법
AI rename(rule-based, 로컬 기본 ON)이 실제로 동작하는지: 텍스트 이미지 투가 후
SQLite 의 `display_name` 이 파일명이 아닌 OCR 유도 이름으로 변경됐는지 DB 직접 조회로 확인.
LLM provider(HTTP/OpenAI/Ollama)·Factory·FoundationModels 는 목/단위 테스트로 검증.

## 체크 항목별 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| provider 추상화(AIService 프로토콜) | ✅ PASS | rename/summarize, 4 구현체 + Factory |
| RuleBasedAIService (로컬 폴백) | ✅ PASS | 8 단위 테스트(OCR/app/무효문자/길이/요약) |
| HTTPAIService (OpenAI 호환, 목 transport) | ✅ PASS | 성공/401/decodeFail/키생략 단위 테스트 |
| AIServiceFactory (선택 로직) | ✅ PASS | 6 케이스(비활성/키유무/provider별) |
| FoundationModelsAIService | 🟡 게이트됨 | macOS 26 #available; 본 호스트는 throw .unavailable(단위 검증 경로) |
| SecretStore (Memory/Keychain) | ✅ PASS | Memory 단위 테스트; Keychain 실접근은 통합 테스트 예정 |
| IntakePipeline AI rename 통합 | ✅ PASS | opt-in 시 displayName 갱신 단위 테스트 |
| **실동작: OCR → rule rename** | ✅ PASS | 투가 이미지 `display_name` = "Supabase auth error 401" (파일명 아님) |

## 증거 (실제 실행)
```
sqlite3 index.sqlite "SELECT display_name, ocr_text FROM shelf_items ORDER BY captured_at DESC LIMIT 3;"
→ Supabase auth error 401 | Supabase auth error 401      ← rename 된 신규 항목
```

## 종합 판정
**PASS** — AI provider 추상화 + rule-based rename이 실제로 동작.
클라우드/온디바이스 LLM은 키/macOS26 환경에서 실검증(설정 UI는 Sprint 8).
다음 Sprint(5: Smart Folder 자동 정리) 진행.
