import Foundation

enum HTTPReadiness {
    static func check(port: Int, path: String) async -> Bool {
        guard (1...65535).contains(port), path.hasPrefix("/"), !path.hasPrefix("//"),
              !path.contains("?"), !path.contains("#"),
              let url = URL(string: "http://127.0.0.1:\(port)\(path)") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse else { return false }
        return (200...299).contains(http.statusCode)
    }
}
