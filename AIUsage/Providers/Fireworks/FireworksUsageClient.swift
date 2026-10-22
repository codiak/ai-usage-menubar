import Foundation

struct FireworksUsageClient: Sendable {
    static let baseURL = URL(string: "https://api.fireworks.ai/v1")!

    let http: HTTPClient

    init(http: HTTPClient = URLSessionHTTPClient()) {
        self.http = http
    }

    func fetchAccounts(apiKey: String) async throws -> HTTPResponse {
        var components = URLComponents(
            url: Self.baseURL.appending(path: "accounts"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "pageSize", value: "2")]
        return try await http.send(HTTPRequest(
            method: .get,
            url: components.url!,
            headers: headers(apiKey)
        ))
    }

    func fetchQuotas(
        apiKey: String,
        accountID: String
    ) async throws -> HTTPResponse {
        var components = URLComponents(
            url: Self.baseURL
                .appending(path: "accounts")
                .appending(path: accountID)
                .appending(path: "quotas"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [URLQueryItem(name: "pageSize", value: "200")]
        return try await http.send(HTTPRequest(
            method: .get,
            url: components.url!,
            headers: headers(apiKey)
        ))
    }

    private func headers(_ apiKey: String) -> [String: String] {
        [
            "Authorization": "Bearer \(apiKey)",
            "Accept": "application/json",
            "User-Agent": "AIUsage/0.1"
        ]
    }
}
