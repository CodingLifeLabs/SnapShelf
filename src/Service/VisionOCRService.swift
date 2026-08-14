import Foundation
import Vision

// Sprint 3: OCR via Vision (offline, free, high-accuracy). Service layer.

public protocol OCRService: Sendable {
    /// Recognize text in the image at `url`. Returns "" if no text is found.
    func recognize(_ url: URL) async throws -> String
}

public final class VisionOCRService: OCRService {
    private let languages: [String]

    public init(languages: [String] = ["en-US", "ko-KR", "ja-JP"]) {
        self.languages = languages
    }

    public func recognize(_ url: URL) async throws -> String {
        try await Task.detached(priority: .utility) { [languages] in
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(url: url, options: [:])
            try handler.perform([request])

            // Vision's origin is bottom-left; sort top-to-bottom by descending minY.
            let observations = request.results ?? []
            let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            return sorted
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }.value
    }
}
