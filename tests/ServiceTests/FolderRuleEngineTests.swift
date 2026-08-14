import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class FolderRuleEngineTests: XCTestCase {

    private func item(app: String? = nil, category: ItemCategory? = nil, ocr: String? = nil, name: String = "shot.png") -> ShelfItem {
        ShelfItem(sourceURL: URL(fileURLWithPath: "/tmp/\(name)"), displayName: name, appName: app, category: category, ocrText: ocr)
    }

    func test_matches_appRule() {
        let engine = FolderRuleEngine(rules: [
            .init(kind: .app, pattern: "ChatGPT", targetSubpath: "ChatGPT")
        ])
        XCTAssertEqual(engine.target(for: item(app: "ChatGPT")), "ChatGPT")
        XCTAssertNil(engine.target(for: item(app: "Safari")))
    }

    func test_matches_keywordInOcrOrName() {
        let engine = FolderRuleEngine(rules: [
            .init(kind: .keyword, pattern: "supabase", targetSubpath: "Supabase")
        ])
        XCTAssertEqual(engine.target(for: item(ocr: "Supabase auth error")), "Supabase")
        XCTAssertEqual(engine.target(for: item(name: "supabase-migration.png")), "Supabase")
    }

    func test_matches_categoryRule() {
        let engine = FolderRuleEngine(rules: [
            .init(kind: .category, pattern: ItemCategory.error.rawValue, targetSubpath: "Errors")
        ])
        XCTAssertEqual(engine.target(for: item(category: .error)), "Errors")
        XCTAssertNil(engine.target(for: item(category: .chat)))
    }

    func test_matches_regexRule() {
        let engine = FolderRuleEngine(rules: [
            .init(kind: .regex, pattern: #"PR-\d+"#, targetSubpath: "PullRequests")
        ])
        XCTAssertEqual(engine.target(for: item(ocr: "Merged PR-1234")), "PullRequests")
        XCTAssertNil(engine.target(for: item(ocr: "no match here")))
    }

    func test_priority_highestWins() {
        let engine = FolderRuleEngine(rules: [
            .init(kind: .keyword, pattern: "supabase", targetSubpath: "Low", priority: 1),
            .init(kind: .keyword, pattern: "supabase", targetSubpath: "High", priority: 50)
        ])
        XCTAssertEqual(engine.target(for: item(ocr: "supabase")), "High")
    }

    func test_disabledRulesAreIgnored() {
        let engine = FolderRuleEngine(rules: [
            .init(kind: .app, pattern: "ChatGPT", targetSubpath: "ChatGPT", enabled: false)
        ])
        XCTAssertNil(engine.target(for: item(app: "ChatGPT")))
    }

    func test_defaultRules_targetSupabaseKeyword() {
        let engine = FolderRuleEngine(rules: FolderRuleEngine.defaultRules)
        XCTAssertEqual(engine.target(for: item(ocr: "Supabase login")), "Supabase")
    }

    func test_defaultRules_targetErrorCategoryOverApp() {
        // error category priority 15 > chat-app keyword; an error in ChatGPT content
        let engine = FolderRuleEngine(rules: FolderRuleEngine.defaultRules)
        let err = ShelfItem(
            sourceURL: URL(fileURLWithPath: "/tmp/x.png"),
            displayName: "x.png",
            appName: "ChatGPT",
            category: .error,
            ocrText: "error code 500"
        )
        XCTAssertEqual(engine.target(for: err), "Errors")
    }
}
