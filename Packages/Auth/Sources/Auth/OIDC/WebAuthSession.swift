#if canImport(WebKit) && os(iOS)
import CoderAPI
import Foundation
import UIKit
import WebKit

/// `OIDCFlow.AuthSession` backed by an in-app `WKWebView` that scrapes the
/// session token from Coder's `/cli-auth` page.
///
/// **Why not ASWebAuthenticationSession?** Coder's `/cli-auth` doesn't honor
/// `redirect_uri` for arbitrary URL schemes — it just renders a token for
/// the user to copy. We need a full WKWebView to inject JS that scrapes the
/// token and feeds it back to native code.
///
/// Flow:
/// 1. Present a sheet hosting a `WKWebView` loaded with `<deployment>/cli-auth`.
/// 2. The user authenticates via whatever method Coder routes them to
///    (OIDC / GitHub / password). The web view follows the redirects.
/// 3. When `/cli-auth` finishes rendering, a `WKUserScript` (injected at
///    document end) scrapes the session token from the DOM and posts it via
///    `window.webkit.messageHandlers.coderTokenBridge.postMessage(token)`.
/// 4. We construct a synthetic `workspaceterminal://auth/callback?session_token=<token>`
///    URL and resolve `OIDCFlow.AuthSession.start`'s continuation, so
///    `OIDCFlow.extractToken` works unchanged.
/// 5. If the user taps Cancel, we throw `.userCanceled`.
public final class LiveWebAuthSession: NSObject, OIDCFlow.AuthSession, @unchecked Sendable {
    public let presentationAnchor: @MainActor () -> UIWindow

    public init(presentationAnchor: @escaping @MainActor () -> UIWindow) {
        self.presentationAnchor = presentationAnchor
    }

    public func start(authURL: URL, callbackScheme: String) async throws -> URL {
        let anchor = presentationAnchor
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            Task { @MainActor in
                let viewController = WebAuthViewController(authURL: authURL, continuation: continuation)
                let nav = UINavigationController(rootViewController: viewController)
                nav.modalPresentationStyle = .pageSheet
                if let sheet = nav.sheetPresentationController {
                    sheet.detents = [.large()]
                    sheet.prefersGrabberVisible = true
                }
                let presenter = anchor().rootViewController?.topmostPresented
                presenter?.present(nav, animated: true)
            }
        }
    }
}

@MainActor
private final class WebAuthViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    private let authURL: URL
    private let continuation: CheckedContinuation<URL, Error>
    private var webView: WKWebView!
    private var resolved = false

    init(authURL: URL, continuation: CheckedContinuation<URL, Error>) {
        self.authURL = authURL
        self.continuation = continuation
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationItem.title = "Sign in to Coder"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )

        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        contentController.add(self, name: "coderTokenBridge")
        contentController.addUserScript(WKUserScript(
            source: scrapeScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        ))
        config.userContentController = contentController
        config.websiteDataStore = .nonPersistent()  // Per-flow cookies; don't leak between sign-ins.

        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        webView.load(URLRequest(url: authURL))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // If the sheet was dismissed without us resolving (user swiped down
        // or tapped Cancel), surface .userCanceled.
        if !resolved {
            resolved = true
            continuation.resume(throwing: OIDCFlow.OIDCError.userCanceled)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "coderTokenBridge",
              let token = message.body as? String,
              !token.isEmpty else { return }
        Task { @MainActor in
            guard !resolved else { return }
            resolved = true
            // Synthesize the callback URL OIDCFlow expects.
            var components = URLComponents()
            components.scheme = Auth.callbackURLScheme
            components.host = Auth.callbackHost
            components.path = Auth.callbackPath
            components.queryItems = [URLQueryItem(name: "session_token", value: token)]
            if let url = components.url {
                continuation.resume(returning: url)
            } else {
                continuation.resume(throwing: OIDCFlow.OIDCError.missingTokenInCallback)
            }
            dismiss(animated: true)
        }
    }
}

private extension UIViewController {
    /// The topmost view controller in the chain of `presentedViewController`s.
    /// Used to pick the right presenter when a sheet is already on screen.
    var topmostPresented: UIViewController {
        var current: UIViewController = self
        while let next = current.presentedViewController {
            current = next
        }
        return current
    }
}

/// JavaScript injected into every Coder page in the WKWebView.
///
/// Tries a sequence of known selectors for the session token. The element is
/// usually a readonly `<input>` rendered inside a `[data-testid="cli-auth-token"]`
/// container, but the implementation is defensive — it also accepts any
/// readonly input or token-shaped text inside a code-style element.
///
/// Polls for ~7s after document-end + watches DOM mutations, since the token
/// may render only after React hydration finishes.
private let scrapeScript = #"""
(function() {
  if (window.__coderTokenScraperInstalled) return;
  window.__coderTokenScraperInstalled = true;

  function tokenLooksValid(value) {
    if (!value) return false;
    var trimmed = ("" + value).trim();
    if (trimmed.length < 20 || trimmed.length > 200) return false;
    return /^[A-Za-z0-9_.\-]+$/.test(trimmed);
  }

  function findToken() {
    var selectors = [
      '[data-testid="cli-auth-token"] input',
      'input[data-testid="cli-auth-token"]',
      '[data-testid="cli-auth-token"]',
      'input[readonly][type="text"]',
      'input[readonly]',
      'input[type="text"][value]'
    ];
    for (var i = 0; i < selectors.length; i++) {
      var el = document.querySelector(selectors[i]);
      if (!el) continue;
      var v = (el.value || el.textContent || '').trim();
      if (tokenLooksValid(v)) return v;
    }
    var nodes = document.querySelectorAll('code, pre, span, div');
    for (var j = 0; j < nodes.length; j++) {
      var text = (nodes[j].textContent || '').trim();
      if (tokenLooksValid(text)) return text;
    }
    return null;
  }

  function tryPost() {
    var t = findToken();
    if (t) {
      try {
        window.webkit.messageHandlers.coderTokenBridge.postMessage(t);
      } catch (e) {}
      return true;
    }
    return false;
  }

  if (tryPost()) return;

  var attempts = 0;
  var interval = setInterval(function() {
    attempts++;
    if (tryPost() || attempts > 30) clearInterval(interval);
  }, 250);

  var observer = new MutationObserver(function() {
    if (tryPost()) observer.disconnect();
  });
  if (document.body) {
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
  }
})();
"""#
#endif
