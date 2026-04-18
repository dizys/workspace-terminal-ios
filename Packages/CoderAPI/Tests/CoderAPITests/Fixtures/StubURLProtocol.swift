import Foundation

/// In-memory `URLProtocol` stub. Register handlers per (method, path-suffix)
/// before running a test; intercepts all requests and returns the configured
/// response.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    struct Response: Sendable {
        let status: Int
        let body: Data
        let headers: [String: String]

        init(status: Int = 200, body: Data = Data(), headers: [String: String] = ["Content-Type": "application/json"]) {
            self.status = status
            self.body = body
            self.headers = headers
        }
    }

    /// (HTTP method, path suffix) → response. Path suffix is matched with
    /// `String.hasSuffix` against the request URL's path so tests don't have
    /// to mirror the full `/api/v2/...` prefix every time.
    static let handlers = LockedHandlers()

    static func register(method: String, pathSuffix: String, response: Response) {
        handlers.set(key: Key(method: method.uppercased(), pathSuffix: pathSuffix), value: response)
    }

    static func reset() {
        handlers.clear()
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let method = (request.httpMethod ?? "GET").uppercased()
        let path = request.url?.path ?? ""
        guard let response = Self.handlers.firstMatch(method: method, path: path) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: response.status,
            httpVersion: "HTTP/1.1",
            headerFields: response.headers
        )!
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Thread-safe handler map.
final class LockedHandlers: @unchecked Sendable {
    private let lock = NSLock()
    private var dict: [Key: StubURLProtocol.Response] = [:]

    func set(key: Key, value: StubURLProtocol.Response) {
        lock.lock(); defer { lock.unlock() }
        dict[key] = value
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        dict.removeAll()
    }

    func firstMatch(method: String, path: String) -> StubURLProtocol.Response? {
        lock.lock(); defer { lock.unlock() }
        for (key, value) in dict where key.method == method && path.hasSuffix(key.pathSuffix) {
            return value
        }
        return nil
    }
}

struct Key: Hashable, Sendable {
    let method: String
    let pathSuffix: String
}

extension URLSession {
    /// Build a `URLSession` configured to use `StubURLProtocol` for all requests.
    static func stubbed() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }
}
