import Foundation

/// In-process HTTP stub. Each `StubURLSession` owns its own handler map,
/// so concurrent tests never interfere with each other.
///
/// Usage:
/// ```swift
/// let stub = StubURLSession()
/// stub.register(method: .get, pathSuffix: "/api/v2/users/me", response: .init(body: ...))
/// let client = Fixtures.client(session: stub.session)
/// ```
final class StubURLSession: @unchecked Sendable {
    /// The configured `URLSession`. Pass it to `LiveCoderAPIClient` (test init).
    let session: URLSession

    /// Stable id baked into the session config so `StubURLProtocol` can look
    /// up the right handler map at request time.
    let sessionID: UUID

    private let handlers = LockedHandlers()

    init() {
        let id = UUID()
        sessionID = id

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        // Bake the session id into a custom header so StubURLProtocol can route.
        config.httpAdditionalHeaders = [StubURLProtocol.sessionIDHeader: id.uuidString]
        session = URLSession(configuration: config)

        StubURLProtocol.registry.set(id: id, handlers: handlers)
    }

    deinit {
        StubURLProtocol.registry.remove(id: sessionID)
        session.invalidateAndCancel()
    }

    func register(method: String, pathSuffix: String, response: StubURLProtocol.Response) {
        handlers.set(key: StubKey(method: method.uppercased(), pathSuffix: pathSuffix), value: response)
    }
}

/// `URLProtocol` that dispatches to the right per-session handler map.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    static let sessionIDHeader = "X-Stub-Session-Id"
    static let registry = StubRegistry()

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

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let method = (request.httpMethod ?? "GET").uppercased()
        let path = request.url?.path ?? ""

        guard let sessionIDString = request.value(forHTTPHeaderField: Self.sessionIDHeader),
              let sessionID = UUID(uuidString: sessionIDString),
              let handlers = Self.registry.handlers(for: sessionID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        guard let response = handlers.firstMatch(method: method, path: path) else {
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

/// Maps session id → its handler map. Safe for concurrent access.
final class StubRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var map: [UUID: LockedHandlers] = [:]

    func set(id: UUID, handlers: LockedHandlers) {
        lock.lock(); defer { lock.unlock() }
        map[id] = handlers
    }

    func remove(id: UUID) {
        lock.lock(); defer { lock.unlock() }
        map.removeValue(forKey: id)
    }

    func handlers(for id: UUID) -> LockedHandlers? {
        lock.lock(); defer { lock.unlock() }
        return map[id]
    }
}

/// Per-session handler map. Thread-safe.
final class LockedHandlers: @unchecked Sendable {
    private let lock = NSLock()
    private var dict: [StubKey: StubURLProtocol.Response] = [:]

    func set(key: StubKey, value: StubURLProtocol.Response) {
        lock.lock(); defer { lock.unlock() }
        dict[key] = value
    }

    func firstMatch(method: String, path: String) -> StubURLProtocol.Response? {
        lock.lock(); defer { lock.unlock() }
        for (key, value) in dict where key.method == method && path.hasSuffix(key.pathSuffix) {
            return value
        }
        return nil
    }
}

struct StubKey: Hashable, Sendable {
    let method: String
    let pathSuffix: String
}
