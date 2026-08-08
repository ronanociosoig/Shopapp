import Testing
import Foundation
import Replay

// StoreRepositoryTests applies `replayFilters` to every recorded fixture as a
// blanket policy (see that file) — but ShopAppServer has no authenticated
// endpoints today, so nothing in our actual .har files demonstrates redaction
// happening. This proves the mechanism directly against a manufactured entry
// carrying exactly the kind of header the policy is meant to catch.
@Suite("Replay — redaction filters")
struct ReplayFilterTests {

    @Test("Authorization header is redacted before a fixture is persisted")
    func headersFilterRedactsAuthorization() async throws {
        let entry = makeEntry(
            headers: [
                HAR.Header(name: "Authorization", value: "Bearer super-secret-token"),
                HAR.Header(name: "Accept", value: "application/json"),
            ]
        )

        let filtered = await Filter.headers(removing: ["Authorization"]).apply(to: entry)

        let authorization = filtered.request.headers.first { $0.name == "Authorization" }
        #expect(authorization?.value == "[FILTERED]")

        let accept = filtered.request.headers.first { $0.name == "Accept" }
        #expect(accept?.value == "application/json")
    }

    @Test("api_key query parameter is redacted, unrelated parameters are untouched")
    func queryParametersFilterRedactsAPIKey() async throws {
        let entry = makeEntry(
            queryString: [
                HAR.QueryParameter(name: "category", value: "Electronics"),
                HAR.QueryParameter(name: "api_key", value: "super-secret-key"),
            ]
        )

        let filtered = await Filter.queryParameters(removing: ["api_key"]).apply(to: entry)

        let apiKey = filtered.request.queryString.first { $0.name == "api_key" }
        #expect(apiKey?.value == "[FILTERED]")

        let category = filtered.request.queryString.first { $0.name == "category" }
        #expect(category?.value == "Electronics")
    }

    // MARK: - Helpers

    private func makeEntry(
        headers: [HAR.Header] = [],
        queryString: [HAR.QueryParameter] = []
    ) -> HAR.Entry {
        HAR.Entry(
            startedDateTime: Date(),
            time: 100,
            request: HAR.Request(
                method: "GET",
                url: "http://localhost:8080/v1/products",
                httpVersion: "HTTP/1.1",
                headers: headers,
                queryString: queryString,
                bodySize: 0
            ),
            response: HAR.Response(
                status: 200,
                statusText: "OK",
                httpVersion: "HTTP/1.1",
                headers: [HAR.Header(name: "Content-Type", value: "application/json")],
                content: HAR.Content(size: 2, mimeType: "application/json", text: "[]"),
                bodySize: 2
            ),
            timings: HAR.Timings(send: 0, wait: 100, receive: 0)
        )
    }
}
