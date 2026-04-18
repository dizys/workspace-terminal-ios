#if os(iOS) || os(visionOS)
import DesignSystem
import SwiftTerm
import SwiftUI
import UIKit

/// SwiftUI wrapper around `SwiftTerm.TerminalView`.
///
/// The byte pipeline is intentionally OUTSIDE TCA (per `docs/performance.md` —
/// no per-byte action dispatch). The caller provides:
///
/// * `inbound` — async sequence of bytes from the PTY transport
/// * `onSend` — closure invoked when the user types (forwards to transport)
/// * `onResize` — closure invoked when the terminal's geometry changes
///
/// SwiftTerm is wrapped only here, per ADR-0002.
public struct WTTerminalView: UIViewRepresentable {
    public typealias Inbound = AsyncThrowingStream<Data, Error>

    private let inbound: () -> Inbound
    private let onSend: @Sendable (Data) -> Void
    private let onResize: @Sendable (Int, Int) -> Void
    private let onError: @Sendable (String) -> Void

    public init(
        inbound: @escaping () -> Inbound,
        onSend: @escaping @Sendable (Data) -> Void,
        onResize: @escaping @Sendable (Int, Int) -> Void = { _, _ in },
        onError: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.inbound = inbound
        self.onSend = onSend
        self.onResize = onResize
        self.onError = onError
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onSend: onSend, onResize: onResize, onError: onError)
    }

    public func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero, font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular))
        view.terminalDelegate = context.coordinator
        view.backgroundColor = UIColor(WTColor.background)
        view.nativeForegroundColor = UIColor(WTColor.textPrimary)
        view.nativeBackgroundColor = UIColor(WTColor.background)
        // Forward iOS taps/scrolls to the host as xterm mouse events when the
        // remote app (tmux, vim, htop) requests mouse mode. SwiftTerm defaults
        // this to true, but we set it explicitly so future SwiftTerm releases
        // can't silently flip the default.
        view.allowMouseReporting = true

        // 1) Suppress SwiftTerm's iOS long-press → context-menu when the host
        //    has mouse mode on. Otherwise a slow tap/drag in tmux pops the
        //    iOS Cut/Copy/Paste menu and (on iOS 16+) can auto-paste clipboard
        //    contents into the terminal.
        context.coordinator.installLongPressGuard(on: view)

        // 2) Two-finger pan → xterm mouse-wheel events. Lets tmux's
        //    "scroll wheel enters copy-mode" binding work on iPhone.
        context.coordinator.installTwoFingerWheelPan(on: view)

        context.coordinator.attach(view: view, inbound: inbound())
        return view
    }

    public func updateUIView(_ uiView: TerminalView, context: Context) {
        context.coordinator.autoFocusIfNeeded(uiView)
        // SwiftTerm adds its panMouse recognizer lazily when mouseMode flips
        // on. Re-clamp every update so 2-finger gestures route to our wheel
        // pan instead of triggering a 1-finger mouse drag.
        context.coordinator.clampSwiftTermPanRecognizers(on: uiView)
    }

    public static func dismantleUIView(_ uiView: TerminalView, coordinator: Coordinator) {
        coordinator.dismantle()
    }

    @MainActor
    public final class Coordinator: NSObject {
        private let onSend: @Sendable (Data) -> Void
        private let onResize: @Sendable (Int, Int) -> Void
        private let onError: @Sendable (String) -> Void
        private weak var view: TerminalView?
        private var pumpTask: Task<Void, Never>?

        init(
            onSend: @escaping @Sendable (Data) -> Void,
            onResize: @escaping @Sendable (Int, Int) -> Void,
            onError: @escaping @Sendable (String) -> Void
        ) {
            self.onSend = onSend
            self.onResize = onResize
            self.onError = onError
        }

        func attach(view: TerminalView, inbound: AsyncThrowingStream<Data, Error>) {
            self.view = view
            pumpTask?.cancel()
            let onError = self.onError                     // local Sendable capture
            pumpTask = Task { [weak self] in               // self is @MainActor → Sendable
                do {
                    for try await chunk in inbound {
                        if Task.isCancelled { return }
                        await self?.feed(chunk)            // hops to MainActor naturally
                    }
                } catch {
                    onError("\(error)")
                }
            }
        }

        private func feed(_ chunk: Data) {
            guard let view else { return }
            view.feed(byteArray: ArraySlice(chunk))
            // Mouse-mode changes happen mid-stream when the host (e.g. tmux)
            // sends DECSET ?1000h. SwiftTerm adds its panMouseGesture lazily
            // at that moment, after all our updateUIView passes have fired.
            // Re-clamp on every inbound chunk so 2-finger gestures route to
            // our wheel-pan instead of SwiftTerm's 1-finger drag.
            clampSwiftTermPanRecognizers(on: view)
        }

        func dismantle() {
            pumpTask?.cancel()
            pumpTask = nil
            view = nil
        }

        // Bridges from the delegate-conformance extension into the Coordinator's
        // private callback closures.
        fileprivate func forwardSend(data: ArraySlice<UInt8>) {
            // DIAG: hex-dump outbound while investigating the 2-finger-paste bug.
            // Mouse-wheel events look like `1B 5B 3C 40 ...M` (button 64) or
            // `1B 5B 3C 41 ...M` (65). Clipboard text would appear as a long
            // ASCII chunk. Remove once paste-on-2-finger root-caused.
            let hex = data.prefix(64).map { String(format: "%02X", $0) }.joined(separator: " ")
            print("[WTTerminalView] outbound \(data.count)B: \(hex)\(data.count > 64 ? " …" : "")")
            onSend(Data(data))
        }
        fileprivate func forwardResize(rows: Int, cols: Int) {
            onResize(rows, cols)
        }

        // MARK: - Auto-focus

        private var didRequestInitialFocus: Bool = false
        private var focusTask: Task<Void, Never>?

        func autoFocusIfNeeded(_ view: TerminalView) {
            guard !didRequestInitialFocus else { return }
            didRequestInitialFocus = true
            // becomeFirstResponder() requires the view to be in a window. The
            // first updateUIView pass usually happens before window-attach, so
            // poll briefly until the view is in the hierarchy.
            focusTask = Task { @MainActor [weak view] in
                for _ in 0..<30 { // up to ~1.5s
                    guard let view else { return }
                    if view.window != nil {
                        _ = view.becomeFirstResponder()
                        return
                    }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
        }

        // MARK: - Gesture customizations

        private var longPressGuard: LongPressGuard?
        private var wheelPanRecognizer: UIPanGestureRecognizer?
        private var wheelPanLastY: CGFloat = 0

        /// Add a UIGestureRecognizerDelegate to ALL UILongPressGestureRecognizers
        /// that suppresses them whenever the remote terminal has mouse mode on.
        /// Diagnostics print every recognizer so we can verify which ones we hit.
        func installLongPressGuard(on view: TerminalView) {
            let guardDelegate = LongPressGuard(view: view)
            self.longPressGuard = guardDelegate
            print("[WTTerminalView] gesture recognizers attached to TerminalView:")
            for (idx, recognizer) in (view.gestureRecognizers ?? []).enumerated() {
                let typeName = String(describing: type(of: recognizer))
                print("  [\(idx)] \(typeName)")
                if let lp = recognizer as? UILongPressGestureRecognizer {
                    lp.delegate = guardDelegate
                    print("       → installed LongPressGuard")
                }
            }
        }

        /// Install a 2-finger pan recognizer that converts vertical drag into
        /// xterm mouse-wheel events when mouse mode is on.
        func installTwoFingerWheelPan(on view: TerminalView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleWheelPan(_:)))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            view.addGestureRecognizer(pan)
            wheelPanRecognizer = pan
            clampSwiftTermPanRecognizers(on: view)
        }

        /// Force every SwiftTerm-added UIPanGestureRecognizer to single-finger
        /// only, so 2-finger gestures don't ALSO trigger a 1-finger mouse
        /// drag (which tmux interprets as drag-select). SwiftTerm adds its
        /// panMouseGesture lazily when mouseMode flips on, so this must be
        /// called from updateUIView too.
        func clampSwiftTermPanRecognizers(on view: TerminalView) {
            for recognizer in view.gestureRecognizers ?? [] {
                guard let pan = recognizer as? UIPanGestureRecognizer,
                      pan !== self.wheelPanRecognizer,
                      pan !== view.panGestureRecognizer, // UIScrollView's own
                      pan.maximumNumberOfTouches != 1
                else { continue }
                pan.maximumNumberOfTouches = 1
            }
        }

        @objc private func handleWheelPan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = self.view else { return }
            let terminal = view.getTerminal()
            // Only forward as wheel events when host has mouse mode on; otherwise
            // let SwiftTerm's UIScrollView handle it as native scroll.
            guard terminal.mouseMode != .off else { return }

            switch recognizer.state {
            case .began:
                wheelPanLastY = recognizer.translation(in: view).y
            case .changed:
                let now = recognizer.translation(in: view).y
                let delta = now - wheelPanLastY
                let cellHeight = max(view.bounds.height / CGFloat(max(terminal.rows, 1)), 1)
                let lines = Int(delta / cellHeight)
                if lines == 0 { return }
                wheelPanLastY = now

                // SGR mouse-wheel: button 64 = wheel up, 65 = wheel down.
                // We pass through the terminal's own sendEvent so encoding
                // matches the active mouseProtocol (sgr / urxvt / utf8).
                let wheelButton = lines > 0 ? 64 : 65
                let count = abs(lines)
                let cols = max(terminal.cols, 1)
                let mid = cols / 2
                for _ in 0..<count {
                    terminal.sendEvent(buttonFlags: wheelButton, x: mid, y: 0)
                }
            default:
                break
            }
        }
    }
}

/// UIGestureRecognizerDelegate that prevents SwiftTerm's long-press
/// (Cut/Copy/Paste menu) from firing while the host has mouse mode on.
/// Without this, a deliberate one-finger drag in tmux pops the iOS context
/// menu and can auto-paste the clipboard.
@MainActor
final class LongPressGuard: NSObject, UIGestureRecognizerDelegate {
    private weak var view: TerminalView?

    init(view: TerminalView) {
        self.view = view
    }

    nonisolated func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        MainActor.assumeIsolated {
            guard let view = self.view else { return true }
            let mouseOn = view.getTerminal().mouseMode != .off
            let allow = !mouseOn
            let typeName = String(describing: type(of: gestureRecognizer))
            print("[LongPressGuard] \(typeName) shouldBegin? mouseMode=\(view.getTerminal().mouseMode) → \(allow ? "allow" : "deny")")
            return allow
        }
    }
}

// Isolated conformance (Swift 6.2). UIKit guarantees these callbacks arrive
// on the main thread, so the `@MainActor` constraint matches the runtime.
extension WTTerminalView.Coordinator: @MainActor TerminalViewDelegate {
    public func send(source: TerminalView, data: ArraySlice<UInt8>) {
        forwardSend(data: data)
    }

    public func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        forwardResize(rows: newRows, cols: newCols)
    }

    public func setTerminalTitle(source: TerminalView, title: String) {}
    public func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
    public func scrolled(source: TerminalView, position: Double) {}
    public func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
    public func bell(source: TerminalView) {}
    public func clipboardCopy(source: TerminalView, content: Data) {
        UIPasteboard.general.string = String(data: content, encoding: .utf8)
    }
    public func clipboardRead(source: TerminalView) -> Data? { nil }
    public func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
    public func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}
}
#endif
