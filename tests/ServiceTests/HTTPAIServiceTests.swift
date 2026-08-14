import XCTest
@testable import SnapShelfService
@testable import SnapShelfTypes

final class HTTPAIServiceTests: XCTestCase {

    private final class MockHTTPClient: HTTPClient, @unchecked Sendable {
        let data: Data
        let response: HTTPURLResponse
        private(set) var lastRequest: URLRequest?

        init(statusCode: Int = 200, body: String) {
            self.data = Data(body.utf8)
            self.response = HTTPURLResponse(
                url: URL(string: "http://test")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
        }

        func data(for request: URLRequest) async throws -> (Data, URLResponse) {
            lastRequest = request
            return (data, response)
        }
    }

    func test_rename_returnsContentFromChoices() async throws {
        let client = MockHTTPClient(body: #"{"choices":[{"message":{"content":"Supabase Login Error"}}]}"#)
        let svc = HTTPAIService(endpoint: URL(string: "http://test")!, apiKey: "k", model: "m", client: client)

        let item = ShelfItem(sourceURL: URL(fileURLWithPath: "/x/s.png"), displayName: "s.png", ocrText: "hi")
        let name = try await svc.rename(item)

        XCTAssertEqual(name, "Supabase Login Error")
        XCTAssertEqual(client.lastRequest?.httpMethod, "POST")
        XCTAssertEqual(client.lastRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer k")
    }

    func test_rename_throwsOnNon200() async {
        let client = MockHTTPClient(statusCode: 401, body: "{}")
        let svc = HTTPAIService(endpoint: URL(string: "http://test")!, apiKey: "k", model: "m", client: client)
        do {
            _ = try await svc.rename(ShelfItem(sourceURL: URL(fileURLWithPath: "/x/s.png"), displayName: "s.png"))
            XCTFail("expected requestFailed")
        } catch AIError.requestFailed(let message) {
            XCTAssertTrue(message.contains("401"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_rename_throwsDecodeFailedWhenShapeWrong() async {
        let client = MockHTTPClient(body: #"{"unexpected":true}"#)
        let svc = HTTPAIService(endpoint: URL(string: "http://test")!, apiKey: "k", model: "m", client: client)
        do {
            _ = try await svc.rename(ShelfItem(sourceURL: URL(fileURLWithPath: "/x/s.png"), displayName: "s.png"))
            XCTFail("expected decodeFailed")
        } catch AIError.decodeFailed {
            // expected
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func test_omitsAuthorizationWhenNoKey() async throws {
        let client = MockHTTPClient(body: #"{"choices":[{"message":{"content":"x"}}]}"#)
        let svc = HTTPAIService(endpoint: URL(string: "http://test")!, apiKey: "", model: "m", client: client)
        _ = try await svc.rename(ShelfItem(sourceURL: URL(fileURLWithPath: "/x/s.png"), displayName: "s.png"))
        XCTAssertNil(client.lastRequest?.value(forHTTPHeaderField: "Authorization"))
    }
}
