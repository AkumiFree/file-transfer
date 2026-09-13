import Foundation

enum EndpointError: LocalizedError {
    case invalidURL
    case unsupportedScheme
    case credentialsNotAllowed
    case queryNotAllowed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return String(localized: "error_invalid_url")
        case .unsupportedScheme: return String(localized: "error_unsupported_url")
        case .credentialsNotAllowed: return String(localized: "error_credentials_url")
        case .queryNotAllowed: return String(localized: "error_query_url")
        }
    }
}

enum EndpointResolver {
    static func resolve(input: String) throws -> ServerEndpoints {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw EndpointError.invalidURL }
        guard var components = URLComponents(string: trimmed) else { throw EndpointError.invalidURL }
        guard components.scheme == "http" || components.scheme == "https" else { throw EndpointError.unsupportedScheme }
        guard let host = components.host, !host.isEmpty else { throw EndpointError.invalidURL }
        guard components.user == nil && components.password == nil else { throw EndpointError.credentialsNotAllowed }
        guard components.query == nil && components.fragment == nil else { throw EndpointError.queryNotAllowed }

        var path = components.path
        while path.hasSuffix("/"), path.count > 1 {
            path.removeLast()
        }
        if path.isEmpty { path = "/" }
        components.path = path
        components.query = nil
        components.fragment = nil
        guard let originURL = components.url else { throw EndpointError.invalidURL }

        let origin = originURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let apiBase = "\(origin)/api/v1"
        let websocketScheme = components.scheme == "https" ? "wss" : "ws"
        let websocketPath = path == "/" ? "/ws" : "\(path)/ws"
        var websocketComponents = URLComponents()
        websocketComponents.scheme = websocketScheme
        websocketComponents.host = components.host
        websocketComponents.port = components.port
        websocketComponents.path = websocketPath
        guard let websocketURL = websocketComponents.url else { throw EndpointError.invalidURL }

        func url(_ path: String) throws -> URL {
            guard let value = URL(string: "\(apiBase)/\(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))") else {
                throw EndpointError.invalidURL
            }
            return value
        }

        return ServerEndpoints(
            origin: origin,
            apiBase: apiBase,
            health: try url("health"),
            auth: try url("auth"),
            users: try url("users"),
            friends: try url("friends"),
            chat: try url("chat"),
            transfers: try url("transfers"),
            releases: try url("releases"),
            websocket: websocketURL
        )
    }
}
