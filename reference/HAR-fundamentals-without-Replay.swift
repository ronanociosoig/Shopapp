// HAR fundamentals without Replay
//
// A minimal, dependency-free sketch of HAR-based request recording and
// playback, built from nothing but Foundation — no Swift 6.1 toolchain,
// no Swift Testing traits required. Compatible with Swift 5.9 and older
// Xcode versions.
//
// Context: Replay (github.com/mattt/Replay) requires swift-tools-version
// 6.1 to build, even though its compiled output can deploy back to iOS 13 —
// every tagged release (0.1.0 through 0.4.0) has required 6.1, so there is
// no older version to pin to as a workaround. If a project's installed
// Xcode genuinely predates a Swift 6.1 compiler, this is what the same
// underlying technique (HAR as the fixture format, URLProtocol as the
// interception point) looks like without the library — record once,
// replay deterministically, offline, in tests.
//
// This is illustrative/reference code, not verified against a real project
// the way the rest of this article's work was — read it, adapt the parts
// that matter (matching strategy, error handling, base64 handling for
// binary bodies), and test it in place before relying on it.
//
// MARK: - What's deliberately left out, vs. the real Replay library
//
// - No composable matchers (.method, .path, .query, ...) — this matches on
//   method + full URL only. Add matching flexibility if pagination cursors
//   or timestamps show up in query strings.
// - No redaction filters — if the recorded traffic has secrets, redact them
//   by hand before committing, or add a filter step to HARRecorder.save.
// - No Swift Testing trait integration — wire this into setUp()/tearDown()
//   (shown below) or your test framework's equivalent instead of a
//   declarative `.replay(...)` argument.
// - No CLI tooling (inspect/status/validate) — a fixture is just JSON; read
//   it with any JSON viewer or a two-line script.

import Foundation

// MARK: - Minimal HAR model

/// A deliberately small subset of the HAR 1.2 spec — just enough to record
/// and replay request/response pairs, including cookies via the response's
/// `Set-Cookie` header. Extend with `cookies`, `queryString`, `timings`,
/// etc. from the full spec (https://github.com/ahmadnassri/har-spec) if
/// your fixtures need them.
enum HAR {
    struct Log: Codable {
        var version: String = "1.2"
        var creator: Creator = Creator(name: "MinimalHAR", version: "1.0")
        var entries: [Entry]
    }

    struct Creator: Codable {
        var name: String
        var version: String
    }

    struct Entry: Codable {
        var startedDateTime: Date
        var request: Request
        var response: Response
    }

    struct Request: Codable {
        var method: String
        var url: String
        var headers: [Header]
        var postData: String?
    }

    struct Response: Codable {
        var status: Int
        var statusText: String
        var headers: [Header]
        var content: Content
    }

    struct Header: Codable {
        var name: String
        var value: String
    }

    struct Content: Codable {
        var mimeType: String
        /// Raw text for JSON/text bodies; base64 for anything else — see `encoding`.
        var text: String
        /// `"base64"` when `text` is base64-encoded; `nil` for plain text.
        var encoding: String?
    }
}

/// The on-disk fixture file — HAR's top-level `{ "log": { ... } }` wrapper.
struct HARFile: Codable {
    var log: HAR.Log
}

// MARK: - Recording

/// Records real HTTP traffic to a HAR-shaped fixture. Performs the actual
/// network call itself via a *separate*, un-intercepted session — this is
/// what stops recording from recursing into its own interception.
final class HARRecorder: @unchecked Sendable {
    private let passthroughSession: URLSession
    private var entries: [HAR.Entry] = []
    private let lock = NSLock()

    init() {
        // Deliberately no custom URLProtocol registered on this
        // configuration — it performs the real network call.
        self.passthroughSession = URLSession(configuration: .ephemeral)
    }

    @discardableResult
    func record(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let started = Date()
        let (data, response) = try await passthroughSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { return (data, response) }

        let isText = String(data: data, encoding: .utf8) != nil
        let entry = HAR.Entry(
            startedDateTime: started,
            request: HAR.Request(
                method: request.httpMethod ?? "GET",
                url: request.url?.absoluteString ?? "",
                headers: (request.allHTTPHeaderFields ?? [:]).map { HAR.Header(name: $0, value: $1) },
                postData: request.httpBody.flatMap { String(data: $0, encoding: .utf8) }
            ),
            response: HAR.Response(
                status: http.statusCode,
                statusText: HTTPURLResponse.localizedString(forStatusCode: http.statusCode),
                headers: http.allHeaderFields.compactMap { key, value in
                    guard let name = key as? String, let value = value as? String else { return nil }
                    return HAR.Header(name: name, value: value)
                },
                content: HAR.Content(
                    mimeType: http.mimeType ?? "application/octet-stream",
                    text: isText ? String(data: data, encoding: .utf8)! : data.base64EncodedString(),
                    encoding: isText ? nil : "base64"
                )
            )
        )

        lock.lock()
        entries.append(entry)
        lock.unlock()

        return (data, response)
    }

    /// Writes every recorded entry to disk as a HAR file.
    ///
    /// `.sortedKeys` is deliberate, not cosmetic: without it, re-recording
    /// an *unchanged* endpoint still produces a full-file diff, because
    /// `JSONEncoder` doesn't guarantee stable key ordering across separate
    /// encode calls. Sorted keys make `git diff` on the fixture actually
    /// mean something — this is the fix for a real, verified problem: the
    /// same issue shows up with Replay's own recordings, since Replay
    /// stores whatever bytes the server sent, key order and all.
    func save(to url: URL) throws {
        let file = HARFile(log: HAR.Log(entries: entries))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: url)
    }
}

// MARK: - Playback

/// Replays a loaded HAR fixture. Register on a `URLSessionConfiguration`
/// (recommended — scoped to one test's session) or globally via
/// `URLProtocol.registerClass(HARPlaybackURLProtocol.self)` if the code
/// under test uses `URLSession.shared` directly and can't be given a
/// custom session.
final class HARPlaybackURLProtocol: URLProtocol {
    /// Set before the session under test makes any requests. Not
    /// thread-safe by design — configure once per test, before use, the
    /// same way Replay's own record/playback state is scoped per test.
    static var fixture: HARFile?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard
            let fixture = Self.fixture,
            let url = request.url,
            let entry = fixture.log.entries.first(where: {
                $0.request.method == (request.httpMethod ?? "GET") && $0.request.url == url.absoluteString
            })
        else {
            client?.urlProtocol(self, didFailWithError: NSError(
                domain: "HARPlaybackURLProtocol",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "No matching HAR entry for \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "")"
                ]
            ))
            return
        }

        let headerFields = Dictionary(uniqueKeysWithValues: entry.response.headers.map { ($0.name, $0.value) })
        let response = HTTPURLResponse(
            url: url,
            statusCode: entry.response.status,
            httpVersion: "HTTP/1.1",
            headerFields: headerFields
        )!

        let body: Data =
            entry.response.content.encoding == "base64"
            ? (Data(base64Encoded: entry.response.content.text) ?? Data())
            : (entry.response.content.text.data(using: .utf8) ?? Data())

        // `.allowed` matters here: it's what makes the URL Loading System
        // process `Set-Cookie` on this response exactly as it would for
        // real traffic. Nothing extra is needed for cookies to land in the
        // session's cookie storage — that's handled by the loading system,
        // not something a URLProtocol implementer does by hand.
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .allowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

// MARK: - Usage: recording (explicit opt-in, mirrors Replay's own philosophy)

/// Not a normal test — gated behind an environment variable so it never
/// records by accident. Run once with `RECORD_FIXTURES=1` to (re)capture,
/// same deliberate-opt-in shape as Replay's `REPLAY_RECORD_MODE=once`.
func recordLoginFixture() async throws {
    guard ProcessInfo.processInfo.environment["RECORD_FIXTURES"] == "1" else {
        print("Skipping recording — set RECORD_FIXTURES=1 to capture login.har")
        return
    }
    let recorder = HARRecorder()
    var request = URLRequest(url: URL(string: "https://staging.example.com/login")!)
    request.httpMethod = "POST"
    try await recorder.record(request)
    try recorder.save(to: URL(fileURLWithPath: "login.har"))
}

// MARK: - Usage: playback + a cookie-specific assertion

import XCTest

final class LoginCookieTests: XCTestCase {
    var session: URLSession!

    override func setUp() {
        super.setUp()

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HARPlaybackURLProtocol.self] + (config.protocolClasses ?? [])
        // A fresh, isolated cookie storage per test. This is the fix for
        // cross-test cookie bleed via the process-wide HTTPCookieStorage.shared
        // that URLSession.shared uses by default — a common, separate cause
        // of "flaky cookie tests" independent of the fixture mechanism.
        config.httpCookieStorage = HTTPCookieStorage()
        session = URLSession(configuration: config)

        let fixtureURL = Bundle(for: Self.self).url(forResource: "login", withExtension: "har")!
        let data = try! Data(contentsOf: fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        HARPlaybackURLProtocol.fixture = try! decoder.decode(HARFile.self, from: data)
    }

    override func tearDown() {
        HARPlaybackURLProtocol.fixture = nil
        session = nil
        super.tearDown()
    }

    func testLoginSetsSessionCookie() async throws {
        var request = URLRequest(url: URL(string: "https://staging.example.com/login")!)
        request.httpMethod = "POST"
        let (_, response) = try await session.data(for: request)
        let http = response as! HTTPURLResponse

        // Foundation already parses Set-Cookie for you — no need to hand-roll
        // this even though HAR itself doesn't require it: HTTPCookie is a
        // standard Foundation type that reads straight off response headers.
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: http.allHeaderFields as! [String: String],
            for: request.url!
        )
        XCTAssertTrue(cookies.contains { $0.name == "session_id" })

        // Confirm it actually landed in *this test's* isolated storage —
        // not some other test's leftover state in a shared global one.
        let stored = session.configuration.httpCookieStorage?.cookies(for: request.url!) ?? []
        XCTAssertTrue(stored.contains { $0.name == "session_id" })
    }
}
