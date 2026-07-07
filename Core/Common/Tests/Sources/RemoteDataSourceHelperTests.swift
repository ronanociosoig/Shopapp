import Testing
import Foundation
import NetworkFoundation
import Common

@Suite("RemoteDataSourceHelper")
struct RemoteDataSourceHelperTests {

    let client = MockNetworkClient()
    let baseURL = URL(string: "https://api.test.example.com/v1")!
    var helper: RemoteDataSourceHelper {
        RemoteDataSourceHelper(client: client, baseURL: baseURL)
    }

    // MARK: - GET (no query items)

    @Test("GET appends path to base URL")
    func getConstructsCorrectURL() async throws {
        try client.setJSON([String]())
        _ = try await helper.get("products") as [String]
        let url = client.receivedRequests.first?.url
        #expect(url?.absoluteString == "https://api.test.example.com/v1/products")
    }

    @Test("GET decodes the response body as the expected type")
    func getDecodesResponse() async throws {
        try client.setJSON(["alpha", "beta"])
        let result: [String] = try await helper.get("items")
        #expect(result == ["alpha", "beta"])
    }

    @Test("GET sends exactly one request")
    func getSendsOneRequest() async throws {
        try client.setJSON([String]())
        _ = try await helper.get("path") as [String]
        #expect(client.receivedRequests.count == 1)
    }

    // MARK: - GET (with query items)

    @Test("GET with query items appends them to the URL")
    func getWithQueryItemsAppendsParams() async throws {
        try client.setJSON([String]())
        _ = try await helper.get(
            "search",
            queryItems: [URLQueryItem(name: "q", value: "laptop")]
        ) as [String]
        let query = client.receivedRequests.first?.url?.query
        #expect(query?.contains("q=laptop") == true)
    }

    @Test("GET with multiple query items includes all of them")
    func getWithMultipleQueryItems() async throws {
        try client.setJSON([String]())
        _ = try await helper.get(
            "search",
            queryItems: [
                URLQueryItem(name: "category", value: "Electronics"),
                URLQueryItem(name: "limit", value: "10"),
            ]
        ) as [String]
        let query = client.receivedRequests.first?.url?.query ?? ""
        #expect(query.contains("category=Electronics") == true)
        #expect(query.contains("limit=10") == true)
    }

    // MARK: - POST (with response)

    @Test("POST with response decodes the body")
    func postDecodesResponse() async throws {
        try client.setJSON("created")
        let result: String = try await helper.post("orders")
        #expect(result == "created")
    }

    @Test("POST sends a POST request")
    func postSendsPostMethod() async throws {
        try client.setJSON("ok")
        _ = try await helper.post("orders") as String
        #expect(client.receivedRequests.first?.httpMethod == "POST")
    }

    @Test("POST sets Content-Type to application/json")
    func postSetsContentType() async throws {
        try client.setJSON("ok")
        _ = try await helper.post("orders") as String
        let contentType = client.receivedRequests.first?.value(forHTTPHeaderField: "Content-Type")
        #expect(contentType == "application/json")
    }

    // MARK: - POST (fire-and-forget)

    @Test("POST fire-and-forget sends a POST request")
    func voidPostSendsPostMethod() async throws {
        try await helper.post("support/tickets")
        #expect(client.receivedRequests.first?.httpMethod == "POST")
    }

    // MARK: - Error propagation

    @Test("Network error from GET is rethrown to the caller")
    func getRethrowsNetworkError() async {
        client.stubError = URLError(.notConnectedToInternet)
        do {
            _ = try await helper.get("anything") as [String]
            Issue.record("Expected error to be thrown")
        } catch {
            #expect((error as? URLError)?.code == .notConnectedToInternet)
        }
    }

    @Test("Network error from POST is rethrown to the caller")
    func postRethrowsNetworkError() async {
        client.stubError = URLError(.timedOut)
        do {
            _ = try await helper.post("anything") as String
            Issue.record("Expected error to be thrown")
        } catch {
            #expect((error as? URLError)?.code == .timedOut)
        }
    }

    // MARK: - Default base URL

    @Test("Default base URL matches the production endpoint")
    func defaultBaseURL() {
        #expect(RemoteDataSourceHelper.defaultBaseURL.absoluteString ==
                "https://api.shopapp.example.com/v1")
    }
}
