import Foundation

/// Low-level HTTP transport. Owns the `URLSession`, attaches auth headers,
/// performs requests, and maps responses to `(Data, HTTPURLResponse)` or
/// `CoderAPIError`.
///
/// Created by `CoderAPIClient`; not used directly by feature code.
public struct HTTPClient: Sendable {
    public let deployment: Deployment
    public let tls: TLSConfig
    public let userAgent: String
    private let session: URLSession
    private let tokenProvider: @Sendable () async -> SessionToken?

    /// - Parameters:
    ///   - deployment: which deployment this client targets
    ///   - tls: TLS validation policy (system trust + user-trusted CAs)
    ///   - userAgent: full User-Agent string sent on every request
    ///   - tokenProvider: async closure that returns the current session
    ///     token, if any. Called per request so tokens can be refreshed.
    public init(
        deployment: Deployment,
        tls: TLSConfig = .default,
        userAgent: String,
        sessionConfiguration: URLSessionConfiguration = .ephemeral,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) {
        self.deployment = deployment
        self.tls = tls
        self.userAgent = userAgent
        self.tokenProvider = tokenProvider

        let delegate = CoderURLSessionDelegate(tls: tls)
        let config = sessionConfiguration
        config.httpAdditionalHeaders = [
            "Accept": "application/json",
            "User-Agent": userAgent,
        ]
        config.waitsForConnectivity = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
    }

    /// Internal initializer for tests — accepts a pre-built `URLSession`
    /// (typically configured with `URLProtocol` stubs).
    init(
        deployment: Deployment,
        tls: TLSConfig = .default,
        userAgent: String,
        session: URLSession,
        tokenProvider: @escaping @Sendable () async -> SessionToken?
    ) {
        self.deployment = deployment
        self.tls = tls
        self.userAgent = userAgent
        self.tokenProvider = tokenProvider
        self.session = session
    }

    /// Execute a request and decode the response body as `T`.
    public func send<T: Decodable & Sendable>(_ request: HTTPRequest) async throws -> T {
        let (data, _) = try await sendRaw(request)
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T  // swiftlint:disable:this force_cast
        }
        do {
            return try JSONCoders.decoder.decode(T.self, from: data)
        } catch {
            throw CoderAPIError.decoding(reason: String(describing: error))
        }
    }

    /// Execute a request that has no JSON body to decode.
    public func sendVoid(_ request: HTTPRequest) async throws {
        _ = try await sendRaw(request)
    }

    /// Execute a request and return the raw response data + metadata.
    public func sendRaw(_ request: HTTPRequest) async throws -> (Data, HTTPURLResponse) {
        let urlRequest = try buildURLRequest(request, token: await tokenProvider())
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        } catch {
            throw CoderAPIError.transport(reason: String(describing: error), underlying: .other)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CoderAPIError.transport(reason: "Non-HTTP response", underlying: .other)
        }
        try validateStatus(http, data: data)
        return (data, http)
    }

    /// Open a streaming download for the given request. Yields lines (suitable
    /// for newline-delimited responses such as SSE / log streams).
    public func stream(_ request: HTTPRequest) async throws -> AsyncThrowingStream<String, Error> {
        let urlRequest = try buildURLRequest(request, token: await tokenProvider())
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await session.bytes(for: urlRequest)
        } catch let urlError as URLError {
            throw mapURLError(urlError)
        }
        guard let http = response as? HTTPURLResponse else {
            throw CoderAPIError.transport(reason: "Non-HTTP response", underlying: .other)
        }
        try validateStatus(http, data: nil)
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    for try await line in bytes.lines {
                        continuation.yield(line)
                        if Task.isCancelled { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Private

    private func buildURLRequest(_ request: HTTPRequest, token: SessionToken?) throws -> URLRequest {
        var components = URLComponents(url: deployment.apiURL(path: request.path), resolvingAgainstBaseURL: false)
        if !request.query.isEmpty {
            components?.queryItems = request.query
        }
        guard let url = components?.url else {
            throw CoderAPIError.invalidURL(request.path)
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (k, v) in request.headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }
        if request.body != nil, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if request.requiresAuth, let token {
            urlRequest.setValue(token.value, forHTTPHeaderField: SessionToken.httpHeaderName)
        }
        if let key = request.idempotencyKey {
            urlRequest.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        return urlRequest
    }

    private func validateStatus(_ http: HTTPURLResponse, data: Data?) throws {
        if (200..<300).contains(http.statusCode) { return }
        let body = data.flatMap { try? JSONCoders.decoder.decode(CoderErrorBody.self, from: $0) }
        let message = body?.userMessage
        let requestID = http.value(forHTTPHeaderField: "X-Request-Id")
        switch http.statusCode {
        case 401: throw CoderAPIError.unauthorized(message: message)
        case 403: throw CoderAPIError.forbidden(message: message)
        case 404: throw CoderAPIError.notFound(message: message)
        case 409: throw CoderAPIError.conflict(message: message)
        default:  throw CoderAPIError.http(status: http.statusCode, message: message, requestID: requestID)
        }
    }

    private func mapURLError(_ error: URLError) -> CoderAPIError {
        let host = error.failingURL?.host ?? deployment.baseURL.host ?? "<unknown>"
        switch error.code {
        case .timedOut:
            return .transport(reason: "Request timed out", underlying: .timeout)
        case .cannotFindHost, .dnsLookupFailed:
            return .transport(reason: "Couldn't resolve \(host)", underlying: .dns)
        case .cannotConnectToHost, .networkConnectionLost:
            return .transport(reason: "Couldn't connect to \(host)", underlying: .connectionRefused)
        case .notConnectedToInternet:
            return .transport(reason: "Offline", underlying: .offline)
        case .secureConnectionFailed,
             .serverCertificateHasBadDate,
             .serverCertificateUntrusted,
             .serverCertificateHasUnknownRoot,
             .serverCertificateNotYetValid,
             .clientCertificateRejected,
             .clientCertificateRequired:
            return .tlsValidation(host: host)
        default:
            return .transport(reason: error.localizedDescription, underlying: .other)
        }
    }
}

/// Sentinel type for endpoints that return no body.
public struct EmptyResponse: Sendable, Decodable {
    public init() {}
}
