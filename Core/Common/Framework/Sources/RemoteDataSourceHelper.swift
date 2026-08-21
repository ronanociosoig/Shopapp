import Foundation
import NetworkFoundation

/// Shared network helper for remote data sources.
/// Wraps `NetworkClient` + a base URL and exposes typed GET/POST methods
/// that decode the response body with `JSONDecoder`, removing the boilerplate that
/// was previously duplicated in every module's remote data source.
public struct RemoteDataSourceHelper: Sendable {
    public static let defaultBaseURL = URL(string: "http://localhost:8080/v1")!

    public let client: NetworkClient
    public let baseURL: URL

    public init(
        client: NetworkClient,
        baseURL: URL = defaultBaseURL
    ) {
        self.client  = client
        self.baseURL = baseURL
    }

    // MARK: - GET

    public func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await client.data(for: URLRequest(url: baseURL.appending(path: path)))
        return try JSONDecoder().decode(T.self, from: data)
    }

    public func get<T: Decodable>(_ path: String, queryItems: [URLQueryItem]) async throws -> T {
        var url = baseURL.appending(path: path)
        url.append(queryItems: queryItems)
        let (data, _) = try await client.data(for: URLRequest(url: url))
        return try JSONDecoder().decode(T.self, from: data)
    }

    // MARK: - POST

    /// POST with a decoded response body.
    public func post<T: Decodable>(_ path: String) async throws -> T {
        let (data, _) = try await client.data(for: postRequest(path))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// POST with no response body (fire-and-forget).
    public func post(_ path: String) async throws {
        _ = try await client.data(for: postRequest(path))
    }

    /// POST with a JSON-encoded request body and a decoded response body.
    public func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        let (data, _) = try await client.data(for: try postRequest(path, body: body))
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// POST with a JSON-encoded request body and no response body (fire-and-forget).
    public func post<Body: Encodable>(_ path: String, body: Body) async throws {
        _ = try await client.data(for: try postRequest(path, body: body))
    }

    private func postRequest(_ path: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    private func postRequest<Body: Encodable>(_ path: String, body: Body) throws -> URLRequest {
        var request = postRequest(path)
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}
