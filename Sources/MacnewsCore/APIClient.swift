import Foundation

public enum APIError: LocalizedError, Equatable, Sendable {
    case invalidURL
    case notFound
    case httpError(Int)
    case decodingError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .notFound:
            return "Feed not found"
        case .httpError(let code):
            return "Server returned HTTP \(code)"
        case .decodingError(let message):
            return "Failed to parse news feed: \(message)"
        case .networkError(let message):
            return message
        }
    }
}

public actor APIClient {
    public static let defaultBaseURL = "https://news.lucianmarin.com"

    private var baseURLString: String
    private let session: URLSession

    public init(
        baseURLString: String = APIClient.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURLString = Self.normalizeBaseURL(baseURLString)
        self.session = session
    }

    public static func normalizeBaseURL(_ raw: String) -> String {
        var trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        if trimmed.hasSuffix("/api") {
            trimmed = String(trimmed.dropLast(4))
        }
        if trimmed.isEmpty {
            return defaultBaseURL
        }
        return trimmed
    }

    public func setBaseURL(_ baseURLString: String) {
        self.baseURLString = Self.normalizeBaseURL(baseURLString)
    }

    public func currentBaseURL() -> String {
        baseURLString
    }

    public func makeURL(path: String, page: Int = 1) throws -> URL {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        guard var components = URLComponents(string: baseURLString + normalizedPath) else {
            throw APIError.invalidURL
        }
        if page > 1 {
            components.queryItems = [URLQueryItem(name: "p", value: String(page))]
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }
        return url
    }

    public func fetchFeed(tab: FeedTab, page: Int = 1) async throws -> PaginatedNewsResponse {
        try await fetchEntries(path: tab.apiPath, page: page)
    }

    public func fetchSite(site: String, page: Int = 1) async throws -> PaginatedNewsResponse {
        let cleaned = site.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty,
              let encoded = cleaned.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            throw APIError.invalidURL
        }
        return try await fetchEntries(path: "/api/\(encoded)", page: page)
    }

    public func fetchEntries(path: String, page: Int = 1) async throws -> PaginatedNewsResponse {
        let url = try makeURL(path: path, page: page)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.networkError("Invalid HTTP response")
        }

        switch http.statusCode {
        case 200..<300:
            break
        case 404:
            throw APIError.notFound
        default:
            throw APIError.httpError(http.statusCode)
        }

        do {
            return try JSONDecoder().decode(PaginatedNewsResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error.localizedDescription)
        }
    }
}
