# SnapShelf — OCR Engine

> Vision `VNRecognizeTextRequest`. 오프라인, 무료, 고정밀. Service 레이어가 소유.

## 1. API

```swift
import Vision

public final class VisionOCRService: OCRService {
    public func recognize(_ url: URL) async throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["ko-KR", "en-US", "ja-JP"]  // 확장 가능
        // 정방향 위→아래 정렬로 재조립
        try await run(on: url, request: request)
        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
    }
}
```

## 2. 파이프라인

```
이미지 URL
  → CGImage 로드
  → VNRecognizeTextRequest(accurate + languageCorrection)
  → 결과 observations 정렬(boundingBox y 역순 → 위→아래; x 정렬)
  → 텍스트 결합
  → (Service) Repo FTS5 색인
```

## 3. 정확도·언어

- `recognitionLevel = .accurate`(속도 < 정확도).
- `usesLanguageCorrection = true` → 단어 단위 보정.
- 다국어: 한국어 우선, 영어, 일본어. 사용자 설정으로 확장.
- 코드/에러/로그 캡처: 등간격 폰트 인식 양호. Dev Mode 는 정규식으로 코드 블록 추출(별도).

## 4. 성능·처리량

- CPU 집중 → 백그라운드 `Task(priority: .utility)` (OCR actor 직렬화).
- 타깃: ≥2장/s(Apple Silicon), Intel 은 ≥1장/s.
- 대량(재색인) 시 큐 + 취소 가능 + 진행률.
- 메모리: 큰 이미지는 다운샘플링 후 처리(`CGImageSourceCreateThumbnailAtPixelSize`).

## 5. 실패 처리

- 이미지 손상/미지원 → 빈 텍스트(원본 보존) + 메타 `ocr_status=failed`.
- Vision 미가용(구 macOS) → 기능 비활성 + 안내.
- 재시도 버튼(항목별) + 전체 재색인(설정).

## 6. OCR 결과 메타

- 각 결과는 boundingBox 보존(선택적: 향후 "이미지 내 텍스트 영역 하이라이트").
- 신뢰도 임계값(기본 0.5) 이하는 스니펫에서 제외 가능.

## 7. 프라이버시

- 100% 온디바이스. 네트워크 0. OCR 텍스트 자체도 로컬(FTS5).
- 클라우드 전송은 AI 요약/검색 시 사용자 옵트인 항목에 한함.
