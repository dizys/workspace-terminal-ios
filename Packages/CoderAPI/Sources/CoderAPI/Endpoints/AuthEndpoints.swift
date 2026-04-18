import Foundation

extension LiveCoderAPIClient {
    public func fetchAuthMethods() async throws -> AuthMethods {
        try await http.send(HTTPRequest(
            method: .get,
            path: "/users/authmethods",
            requiresAuth: false
        ))
    }

    public func login(email: String, password: String) async throws -> SessionToken {
        let body = LoginRequest(email: email, password: password)
        let data: Data
        do {
            data = try JSONCoders.encoder.encode(body)
        } catch {
            throw CoderAPIError.encoding(reason: String(describing: error))
        }
        let response: LoginResponse = try await http.send(HTTPRequest(
            method: .post,
            path: "/users/login",
            body: data,
            requiresAuth: false
        ))
        return SessionToken(response.sessionToken)
    }

    public func fetchCurrentUser() async throws -> User {
        try await http.send(HTTPRequest(
            method: .get,
            path: "/users/me"
        ))
    }

    public func logout() async throws {
        try await http.sendVoid(HTTPRequest(
            method: .post,
            path: "/users/logout"
        ))
    }
}
