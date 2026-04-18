import Foundation
import Testing
@testable import CoderAPI

@Suite("AuthMethods")
struct AuthMethodsTests {
    @Test("Decodes the documented Coder authmethods response shape")
    func decodes() throws {
        let json = #"""
        {
          "password": { "enabled": true },
          "github":   { "enabled": false },
          "oidc":     { "enabled": true, "signInText": "Login with Okta", "iconUrl": "https://example.com/okta.png" }
        }
        """#
        let methods = try JSONCoders.decoder.decode(AuthMethods.self, from: Data(json.utf8))
        #expect(methods.password.enabled)
        #expect(!methods.github.enabled)
        #expect(methods.oidc.enabled)
        #expect(methods.oidc.signInText == "Login with Okta")
        #expect(methods.oidc.iconURL?.absoluteString == "https://example.com/okta.png")
    }

    @Test("enabledMethods returns OIDC > GitHub > password order")
    func order() {
        let methods = AuthMethods(
            password: .init(enabled: true),
            github: .init(enabled: true),
            oidc: .init(enabled: true, signInText: "Continue with Auth0", iconURL: nil)
        )
        let enabled = methods.enabledMethods
        #expect(enabled.count == 3)
        if case let .oidc(text, _) = enabled[0] {
            #expect(text == "Continue with Auth0")
        } else {
            Issue.record("Expected OIDC first")
        }
        #expect(enabled[1] == .github)
        #expect(enabled[2] == .password)
    }

    @Test("Disabled methods are filtered out")
    func filtered() {
        let methods = AuthMethods(
            password: .init(enabled: false),
            github: .init(enabled: false),
            oidc: .init(enabled: true, signInText: nil, iconURL: nil)
        )
        #expect(methods.enabledMethods.count == 1)
    }
}
