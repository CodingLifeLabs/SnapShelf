# Evaluator Report — Sprint 5

실행 일시: 2026-08-14
검증 대상: SnapShelf.app (Debug, + Smart Folder organize)

## 결과: PASS

## 검증 방법
Smart Folder 자동 정리가 실제로 동작하는지: 텍스트 이미지 투가 후
(1) SQLite 의 source_url/app_name/display_name, (2) 실제 파일시스템 이동(Library/Supabase/) 을 모두 확인.

## 체크 항목별 결과

| 항목 | 결과 | 비고 |
|------|------|------|
| 소스 감지(SourceDetector) | ✅ PASS | OCR 키워드로 app="Supabase" 추정 (TCC 없음) |
| FolderRule 엔진(우선순위/키워드/정규식/카테고리) | ✅ PASS | 8 단위 테스트 + defaultRules |
| Organizer 파일 이동 | ✅ PASS | 5 단위 테스트(이동/카테고리/무매치/결측/충돌) |
| IntakePipeline 통합 | ✅ PASS | OCR→rename→organize 순서 |
| **실동작: 파일이 Library/Supabase/ 로 이동** | ✅ PASS | source_url 갱신 + 파일시스템 이동 + Inbox 제거 |

## 증거 (실제 실행)
```
DB:  Supabase auth error 401 | Supabase | .../Library/Supabase/eval-text-1786684896.png
FS:  Library/Supabase/eval-text-1786684896.png  (생성됨)
     Inbox/  ← 해당 파일 제거됨(이동 완료)
```

## 범위 비고
- TCC 안전 경로(앱 제어 Library 폴더 내)로 구현/검증.
- 사용자 폴더(~/Pictures/Screenshots) 감시 + 접근성 기반 정확 감지는
  권한 온보딩과 함께 설정(향후)에서 확장.

## 종합 판정
**PASS** — 캡처→OCR→AI 리네임→Smart Folder 자동 정리가 파일 이동까지 실제로 동작.
다음 Sprint(6: 검색/타임라인/컬렉션 UI) 진행.
