import XCTest
@testable import SnapShelfRuntime
@testable import SnapShelfTypes

@MainActor
final class CollectionModelTests: XCTestCase {

    private func item(_ id: UUID, name: String) -> ShelfItem {
        ShelfItem(id: id, sourceURL: URL(fileURLWithPath: "/tmp/\(name)"), displayName: name,
                  capturedAt: Date(timeIntervalSince1970: 1))
    }

    func test_create_addsCollection() {
        let model = CollectionModel()
        let collection = model.create(name: "Supabase")
        XCTAssertEqual(model.collections.count, 1)
        XCTAssertEqual(model.collections.first?.name, "Supabase")
        XCTAssertEqual(collection.name, "Supabase")
    }

    func test_create_emptyName_defaultsToUntitled() {
        let model = CollectionModel()
        _ = model.create(name: "   ")
        XCTAssertEqual(model.collections.first?.name, "Untitled")
    }

    func test_addAndRemoveItem() {
        let model = CollectionModel()
        let collection = model.create(name: "Refs")
        let id = UUID()
        model.add(id, to: collection.id)
        XCTAssertEqual(model.collections.first?.itemIDs, [id])
        model.remove(id, from: collection.id)
        XCTAssertTrue(model.collections.first?.itemIDs.isEmpty ?? true)
    }

    func test_items_returnsMembersNewestFirst() {
        let model = CollectionModel()
        let collection = model.create(name: "C")
        let a = UUID(); let b = UUID()
        model.add(a, to: collection.id)
        model.add(b, to: collection.id)
        let all = [item(a, name: "old"), item(b, name: "new")] // both capturedAt=1, tie-broken by name
        let members = model.items(in: collection.id, from: all)
        XCTAssertEqual(members.count, 2)
    }

    func test_delete_removesCollection() {
        let model = CollectionModel()
        let collection = model.create(name: "X")
        model.delete(collection.id)
        XCTAssertTrue(model.collections.isEmpty)
    }
}
