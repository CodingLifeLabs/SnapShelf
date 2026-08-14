import XCTest
@testable import SnapShelfService

final class SecretStoreTests: XCTestCase {

    func test_memoryStore_writeReadDelete() {
        let store = MemorySecretStore()
        XCTAssertNil(store.read("openai_api_key"))

        store.write("openai_api_key", value: "sk-test-123")
        XCTAssertEqual(store.read("openai_api_key"), "sk-test-123")

        store.delete("openai_api_key")
        XCTAssertNil(store.read("openai_api_key"))
    }

    func test_memoryStore_isolatesKeys() {
        let store = MemorySecretStore()
        store.write("a", value: "1")
        store.write("b", value: "2")
        XCTAssertEqual(store.read("a"), "1")
        XCTAssertEqual(store.read("b"), "2")
    }
}
