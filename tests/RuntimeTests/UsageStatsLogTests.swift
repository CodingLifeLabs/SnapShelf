import XCTest
@testable import SnapShelfRuntime
@testable import SnapShelfTypes

// Sprint 12: UsageStatsLog record/persist/load/clear/cap (PrivacyLog pattern).

final class UsageStatsLogTests: XCTestCase {
    var file: URL!
    var log: UsageStatsLog!

    override func setUp() {
        file = FileManager.default.temporaryDirectory
            .appendingPathComponent("usage-\(UUID().uuidString).jsonl")
        log = UsageStatsLog(fileURL: file)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: file)
    }

    func testEmptyLogReturnsNoEvents() async {
        let events = await log.events()
        XCTAssertTrue(events.isEmpty)
    }

    func testRecordPersistsAcrossInstances() async {
        await log.record(kind: .captured)
        await log.record(kind: .searched)
        // Fresh instance reads the same file — persistence, not memory.
        let reloaded = UsageStatsLog(fileURL: file)
        let events = await reloaded.events()
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events.first?.kind, .captured)
        XCTAssertEqual(events.last?.kind, .searched)
    }

    func testCapKeepsMostRecent() async {
        let small = UsageStatsLog(fileURL: file, maxEvents: 3)
        for i in 0..<5 {
            await small.record(UsageEvent(timestamp: Date(timeIntervalSince1970: Double(i)), kind: .captured))
        }
        let events = await small.events()
        XCTAssertEqual(events.count, 3)
        // Chronological order retained; the two oldest were dropped.
        XCTAssertEqual(events.first?.timestamp, Date(timeIntervalSince1970: 2))
        XCTAssertEqual(events.last?.timestamp, Date(timeIntervalSince1970: 4))
    }

    func testDefaultCapIs2000() async {
        let capped = UsageStatsLog(fileURL: file)
        let mirror = Mirror(reflecting: capped)
        let maxEvents = mirror.children.first { $0.label == "maxEvents" }?.value as? Int
        XCTAssertEqual(maxEvents, 2000)
    }

    func testClearRemovesEverything() async {
        await log.record(kind: .pinned)
        await log.clear()
        let events = await log.events()
        XCTAssertTrue(events.isEmpty)
    }

    func testCorruptedLineIsSkippedNotFatal() async {
        await log.record(kind: .captured)
        try? "not-json\n".write(to: file, atomically: true, encoding: .utf8)
        let events = await log.events()
        // A corrupt line yields zero decodable events, not a crash.
        XCTAssertTrue(events.isEmpty)
    }

    func testRecordEventConvenienceMatches() async {
        let event = UsageEvent(kind: .stowed)
        await log.record(event)
        let events = await log.events()
        // ISO8601 persistence drops sub-second precision, so compare identity
        // and kind rather than full Date equality.
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.id, event.id)
        XCTAssertEqual(events.first?.kind, event.kind)
        let stored = events.first?.timestamp.timeIntervalSince1970
        let original = event.timestamp.timeIntervalSince1970
        if let stored {
            XCTAssertEqual(stored, original.rounded(), accuracy: 1.0)
        } else {
            XCTFail("missing timestamp")
        }
    }
}
