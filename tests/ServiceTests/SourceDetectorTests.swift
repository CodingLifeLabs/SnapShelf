import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class SourceDetectorTests: XCTestCase {

    private let detector = SourceDetector()

    // MARK: - detectApp

    func test_detectApp_fromOcrKeyword() {
        XCTAssertEqual(detector.detectApp(ocrText: "Supabase auth error", filename: "shot.png"), "Supabase")
    }

    func test_detectApp_fromFilename() {
        XCTAssertEqual(detector.detectApp(ocrText: nil, filename: "CleanShot X.png"), nil)
        XCTAssertEqual(detector.detectApp(ocrText: nil, filename: "ChatGPT response.png"), "ChatGPT")
    }

    func test_detectApp_caseInsensitive() {
        XCTAssertEqual(detector.detectApp(ocrText: "claude.ai conversation", filename: "x.png"), "Claude")
    }

    func test_detectApp_unknownReturnsNil() {
        XCTAssertNil(detector.detectApp(ocrText: "random text nothing known", filename: "x.png"))
    }

    // MARK: - detectCategory

    func test_detectCategory_errorFromStacktrace() {
        XCTAssertEqual(detector.detectCategory(app: nil, ocrText: "Traceback (most recent call last)"), .error)
        XCTAssertEqual(detector.detectCategory(app: nil, ocrText: "error code 401"), .error)
    }

    func test_detectCategory_byApp() {
        XCTAssertEqual(detector.detectCategory(app: "ChatGPT", ocrText: "hello"), .chat)
        XCTAssertEqual(detector.detectCategory(app: "VSCode", ocrText: "code"), .code)
        XCTAssertEqual(detector.detectCategory(app: "Figma", ocrText: ""), .design)
    }

    func test_detectCategory_receiptAndInvoice() {
        XCTAssertEqual(detector.detectCategory(app: nil, ocrText: "Total $42.00"), .receipt)
        XCTAssertEqual(detector.detectCategory(app: nil, ocrText: "Invoice #123 Bill to:"), .invoice)
    }

    func test_detectCategory_otherWhenNothing() {
        XCTAssertEqual(detector.detectCategory(app: nil, ocrText: "just some notes"), .other)
    }
}
