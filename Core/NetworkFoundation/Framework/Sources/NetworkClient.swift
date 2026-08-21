import Foundation

// MARK: - Protocol

public protocol NetworkClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// MARK: - Live

public final class DefaultNetworkClient: NetworkClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

// MARK: - Unimplemented (for testing)

public final class UnimplementedNetworkClient: NetworkClient {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        fatalError("UnimplementedNetworkClient.data(for:) — inject a real client or stub in tests")
    }
}

// MARK: - Mock (for testing)

/// Records every request and returns configurable stub data.
/// Use in test targets to verify URL construction, query parameters, and response decoding.
public final class MockNetworkClient: NetworkClient, @unchecked Sendable {
    public var stubData: Data = Data()
    public var stubError: Error?
    public private(set) var receivedRequests: [URLRequest] = []

    public init() {}

    /// Encodes `value` as JSON and stores it as the stub response body.
    public func setJSON<T: Encodable>(_ value: T) throws {
        stubData = try JSONEncoder().encode(value)
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        receivedRequests.append(request)
        if let error = stubError { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (stubData, response)
    }
}
