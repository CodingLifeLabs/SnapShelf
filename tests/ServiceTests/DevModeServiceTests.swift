import XCTest
import SnapShelfTypes
@testable import SnapShelfService

// Sprint 8: DevModeService extraction tests using realistic OCR-ish input
// from an error screenshot.

final class DevModeServiceTests: XCTestCase {
    let service = DevModeService()

    let sample = """
    Xcode build output:
    error: cannot find type 'Foo' in scope
    at /Users/dev/App/src/main.swift:42:23
        let foo = Foo()
        foo.bar()
        foo.baz()
    Fatal error: Unexpectedly found nil while unwrapping an Optional value
    """

    func testExtractFindsErrorLines() {
        let extraction = service.extract(fromOCRText: sample)
        XCTAssertTrue(extraction.errorLines.contains {
            $0.contains("cannot find type 'Foo'")
        })
        XCTAssertTrue(extraction.errorLines.contains {
            $0.contains("Fatal error")
        })
    }

    func testExtractFindsReferences() {
        let extraction = service.extract(fromOCRText: sample)
        let found = extraction.references.contains("main.swift:42")
            || extraction.references.contains("/Users/dev/App/src/main.swift:42")
        XCTAssertTrue(found)
    }

    func testExtractFindsIndentedCodeBlock() {
        let extraction = service.extract(fromOCRText: sample)
        XCTAssertEqual(extraction.codeBlocks.count, 1)
        XCTAssertTrue(extraction.codeBlocks[0].contains("foo.bar()"))
    }

    func testExtractFencedBlock() {
        let text = """
        before
        ```swift
        let x = 1
        let y = 2
        ```
        after
        """
        let extraction = service.extract(fromOCRText: text)
        XCTAssertEqual(extraction.codeBlocks.count, 1)
        XCTAssertTrue(extraction.codeBlocks[0].contains("let x = 1"))
    }

    func testEmptyInputYieldsEmptyExtraction() {
        let extraction = service.extract(fromOCRText: "")
        XCTAssertTrue(extraction.isEmpty)
    }

    func testSearchQueryPrefersFirstErrorLine() {
        let query = service.searchQuery(for: service.extract(fromOCRText: sample))
        XCTAssertTrue(query.contains("cannot find type"))
    }

    func testSearchURLBuilding() throws {
        let url = try XCTUnwrap(service.searchURL(query: "swift nil crash", site: .stackOverflow))
        let absolute = url.absoluteString
        XCTAssertTrue(absolute.contains("google.com/search"))
        XCTAssertTrue(absolute.contains("site%3Astackoverflow.com")
                      || absolute.contains("site:stackoverflow.com"))
    }

    func testSearchURLEmptyQueryIsNil() {
        XCTAssertNil(service.searchURL(query: ""))
    }

    func testClaudeURLContainsQuery() throws {
        let extraction = service.extract(fromOCRText: sample)
        let url = try XCTUnwrap(service.claudeURL(extraction: extraction))
        XCTAssertTrue(url.absoluteString.contains("claude.ai/new"))
    }
}
