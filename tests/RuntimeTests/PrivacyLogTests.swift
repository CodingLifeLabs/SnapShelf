import XCTest
import SnapShelfTypes
@testable import SnapShelfRuntime

// Sprint 8: PrivacyLog append/cap/clear round-trip tests.

final class PrivacyLogTests: XCTestCase {
    var file: URL!
    var log: PrivacyLog!

    override func setUp() {
        file = FileManager.default.temporaryDirectory
            .appendingPathComponent("privacy-\(UUID().uuidString).jsonl")
        log = PrivacyLog(fileURL: file)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
    }

    func testEmptyLogReturnsNoEvents() async {
        let events = await log.all()
        XCTAssertTrue(events.isEmpty)
    }

    func testRecordPersistsAndAllIsNewestFirst() async {
        let first = PrivacyEvent(destination: "OpenAI", payloadSummary: "OCR text")
        try? await Task.sleep(nanoseconds: 20_000_000)
        let second = PrivacyEvent(destination: "Local", payloadSummary: "rename only")
        await log.record(first)
        await log.record(second)
        let events = await log.all()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.destination, second.destination)
        XCTAssertEqual(events.last?.destination, first.destination)
    }

    func testCapKeepsMostRecent() async {
        let small = PrivacyLog(fileURL: file, maxEvents: 3)
        for i in 0..<5 {
            await small.record(PrivacyEvent(destination: "d\(i)", payloadSummary: "p\(i)"))
        }
        let events = await small.all()
        XCTAssertEqual(events.count, 3)
        XCTAssertEqual(events.first?.destination, "d4")
        XCTAssertEqual(events.last?.destination, "d2")
    }

    func testClearRemovesEverything() async {
        await log.record(PrivacyEvent(destination: "X", payloadSummary: "y"))
        await log.clear()
        let events = await log.all()
        XCTAssertTrue(events.isEmpty)
    }

    func testRoundTripPreservesPayload() async {
        let event = PrivacyEvent(
            destination: "Anthropic claude-sonnet-5",
            payloadSummary: "Image (512px, 88 KB)"
        )
        await log.record(event)
        let events = await log.all()
        XCTAssertEqual(events.first?.payloadSummary, event.payloadSummary)
    }
}
