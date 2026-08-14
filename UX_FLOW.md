# SnapShelf — UX Flow

> 핵심 루프와 주요 경로. 화면 명세는 `SCREEN_STATES.md`, 애니메이션은 `ANIMATION_SPEC.md`.

## 0. 최초 실행 (Onboarding)

```
앱 실행(메뉴바 상주, Dock 없음)
  → 권한 요청 카드: "스크린샷 폴더 접근" (Desktop/Pictures)
      ├─ 허용 → 감시 시작
      └─ 거부 → 폴백: "직접 폴더 선택" → NSSavePanel 경로 지정
  → (선택) "AI 켜기" → provider 선택(온디바이스 권장) / 건너뛰기
  → 완료: "이제 ⌘⇧4 로 찍어보세요" 가이드 + 메뉴바 트레이 애니메이션
```

## 1. 핵심 루프: 캡처 → Shelf

```
사용자 ⌘⇧4 (시스템 스크린샷)
  → macOS 가 ~/Pictures/Screenshots(또는 Desktop) 에 파일 저장
  → FSEvents 감지
  → 우하단에서 Shelf 로 "빨려드는" 애니메이션(≤200ms)
  → ShelfItem 5초간 떠 있음(호버 시 유지)
  → 이 시간에 가능:
      • 복사(⌘C)        • 드래그(타 앱으로)   • 공유(시트)
      • OCR 보기        • AI 요약(옵트인)      • 핀(항상 위)
  → 5초 후: 축소하여 히스토리 스택으로(또는 핀 유지)
```

상태: `capture → intake(애니메이션) → resting(5s) → stowed(히스토리)`

## 2. 다시 찾기: 검색

```
메뉴바 아이콘 클릭 (또는 ⌘Space-SnapShelf 단축키)
  → ShelfPanel 열림 + 검색입력 자동 포커스
  → 타이핑:
      "Supabase"           → FTS5 즉시 결과(OCR 텍스트 하이라이트)
      "지난달 ChatGPT API" → AI 검색(옵트인 시) → 의미 일치 결과
  → 결과 항목: 클릭(미리보기) / 드래그(복사) / ⌘C(경로 복사)
```

## 3. 자동 정리: Smart Folder

```
(백그라운드, 캡처 후 수 초 내)
  IntakePipeline:
    OCR → 분류(앱/도메인/AI) → 이름변경(옵션) → 규칙 적용
  → 파일이 자동으로 폴더로 이동
      Screenshots/2026/08/Chrome/Screenshot 08-14 10-22.png
        또는 Screenshots/ChatGPT/...
  → Library 사이드바에 폴더 트리 반영(실시간)
  → 사용자: Library 에서 폴더/타임라인 탐색
```

## 4. 타임라인

```
Library → "오늘" 타임라인 탭
  → 시간축: 오전 회의(Slack) → VSCode → Chrome → Claude → Figma
  → 시점 스크럽 → 해당 항목 그룹 하이라이트
```

## 5. Dev Mode (개발자)

```
VSCode 에러 캡처
  → ShelfItem 액션 "Dev Mode"
      → OCR → 오류 코드/스택 추출
      → 자동 검색(StackOverflow/GitHub) + Claude 실행 옵션
      → 결과 복사
```

## 6. 라이프사이클 종료

```
설정: Auto Cleanup N일(기본 30)
  → N일 경과 임시 항목 → 휴지통(미리보기 + 실행취소 보장)
중복 탐지:
  → 95% 유사 항목 그룹 → "삭제 추천" 배너 → 사용자 승인 시 보관본 1개
```

## 7. 에지 케이스

| 상황 | 처리 |
|------|------|
| 권한 거부 | 폴백 폴더 선택 + 안내 토스트 |
| OCR 실패 | 원본 보존, 메타만 저장, 재시도 버튼 |
| AI 미옵트인 | AI 메뉴는 비활성(점선) + "AI 켜기"로 유도 |
| 폴더 이동 충돌 | 동일명 시 타임스탬프 접미; 사용자 확인 |
| 대량 캡처(버스트) | 합리적 디바운스 + 큐 처리, UI 멈춤 없음 |
