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
///    Only Coder's `id-secret` format is accepted.
/// 4. We construct a synthetic `workspaceterminal://auth/callback?session_token=<token>`
///    URL and resolve `OIDCFlow.AuthSession.start`'s continuation.
/// 5. **Fallback:** if scraping fails (DOM changed, token not visible), the
///    user can tap "Paste token" in the navigation bar, copy the token via
///    Coder's own "Copy session token" button, and paste it into a sheet.
/// 6. If the user dismisses without resolving, we throw `.userCanceled`.
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

/// A Coder session token has the shape `<id>-<secret>` where both halves
/// are alphanumeric. Reject anything else — older versions of the scraper
/// got fooled by random alphanumeric DOM nodes.
///
/// Public so the OIDCFlow layer + tests can share the same definition.
public enum CoderTokenFormat {
    /// Coder uses 10-char IDs and 22+ char secrets, but be lenient about
    /// length to survive future tweaks. Single dash as separator.
    public static let pattern = #"^[A-Za-z0-9]{8,40}-[A-Za-z0-9]{16,80}$"#

    public static func isValid(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.range(of: pattern, options: .regularExpression) != nil
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
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Paste token",
            style: .plain,
            target: self,
            action: #selector(pasteTokenTapped)
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
        if !resolved {
            resolved = true
            continuation.resume(throwing: OIDCFlow.OIDCError.userCanceled)
        }
    }

    @objc private func cancelTapped() {
        dismiss(animated: true)
    }

    @objc private func pasteTokenTapped() {
        let alert = UIAlertController(
            title: "Paste session token",
            message: "On Coder's page, tap 'Copy session token', then paste it here.",
            preferredStyle: .alert
        )
        alert.addTextField { tf in
            tf.placeholder = "id-secret"
            tf.autocapitalizationType = .none
            tf.autocorrectionType = .no
            tf.spellCheckingType = .no
            tf.smartDashesType = .no
            tf.smartQuotesType = .no
            tf.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
            // Pre-fill with the clipboard if it looks like a Coder token.
            if let clip = UIPasteboard.general.string, CoderTokenFormat.isValid(clip) {
                tf.text = clip
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Sign in", style: .default) { [weak self, weak alert] _ in
            guard let self, let alert,
                  let raw = alert.textFields?.first?.text else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard CoderTokenFormat.isValid(trimmed) else {
                self.showInvalidTokenAlert()
                return
            }
            self.deliverToken(trimmed)
        })
        present(alert, animated: true)
    }

    private func showInvalidTokenAlert() {
        let alert = UIAlertController(
            title: "That doesn't look like a session token",
            message: "Coder session tokens are formatted as 'id-secret'. Try copying the full string from the page.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    // MARK: - WKScriptMessageHandler

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "coderTokenBridge",
              let token = message.body as? String,
              CoderTokenFormat.isValid(token) else { return }
        Task { @MainActor in
            self.deliverToken(token)
        }
    }

    private func deliverToken(_ token: String) {
        guard !resolved else { return }
        resolved = true
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
/// Looks for a Coder session token (formatted `id-secret`). Tries known
/// selectors first (data-testid, readonly inputs), then any DOM text node
/// that matches the strict format. Polls + watches mutations to handle
/// React hydration timing.
private let scrapeScript = #"""
(function() {
  if (window.__coderTokenScraperInstalled) return;
  window.__coderTokenScraperInstalled = true;

  // Coder session tokens are exactly <id>-<secret>; reject anything else.
  var TOKEN_REGEX = /\b([A-Za-z0-9]{8,40}-[A-Za-z0-9]{16,80})\b/;

  function extractTokenFrom(text) {
    if (!text) return null;
    var s = ("" + text).trim();
    var m = s.match(TOKEN_REGEX);
    return m ? m[1] : null;
  }

  function findToken() {
    // Try inputs first (most reliable).
    var inputs = document.querySelectorAll('input');
    for (var i = 0; i < inputs.length; i++) {
      var t = extractTokenFrom(inputs[i].value);
      if (t) return t;
    }
    // Then specific Coder containers.
    var containers = document.querySelectorAll(
      '[data-testid="cli-auth-token"], [class*="token" i], [class*="Token"]'
    );
    for (var j = 0; j < containers.length; j++) {
      var t2 = extractTokenFrom(containers[j].textContent);
      if (t2) return t2;
    }
    // Then any visible code/pre/span that looks like a token.
    var nodes = document.querySelectorAll('code, pre, span, div, p');
    for (var k = 0; k < nodes.length; k++) {
      var t3 = extractTokenFrom(nodes[k].textContent);
      if (t3) return t3;
    }
    return null;
  }

  function tryPost() {
    var t = findToken();
    if (t) {
      try { window.webkit.messageHandlers.coderTokenBridge.postMessage(t); } catch (e) {}
      return true;
    }
    return false;
  }

  if (tryPost()) return;

  var attempts = 0;
  var interval = setInterval(function() {
    attempts++;
    if (tryPost() || attempts > 40) clearInterval(interval);
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
