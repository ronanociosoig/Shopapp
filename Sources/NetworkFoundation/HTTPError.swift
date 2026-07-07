import Foundation

public enum HTTPError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case statusCode(Int)
    case decodingFailed(String)
    case networkUnavailable
    case timeout
}
