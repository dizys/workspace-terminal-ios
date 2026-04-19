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
    /// Whether this view is the visible/active terminal. The container (e.g.
    /// TabView in TerminalSessionsView) flips this to true for the
    /// currently-selected tab so the view can claim first-responder status.
    private let isActive: Bool
    private let theme: TerminalTheme

    public init(
        inbound: @escaping () -> Inbound,
        onSend: @escaping @Sendable (Data) -> Void,
        onResize: @escaping @Sendable (Int, Int) -> Void = { _, _ in },
        onError: @escaping @Sendable (String) -> Void = { _ in },
        isActive: Bool = true,
        theme: TerminalTheme = .default
    ) {
        self.inbound = inbound
        self.onSend = onSend
        self.onResize = onResize
        self.onError = onError
        self.isActive = isActive
        self.theme = theme
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(onSend: onSend, onResize: onResize, onError: onError)
    }

    public func makeUIView(context: Context) -> TerminalView {
        let view = TerminalView(frame: .zero, font: UIFont.monospacedSystemFont(ofSize: 14, weight: .regular))
        view.terminalDelegate = context.coordinator
        theme.apply(to: view)
        // Forward iOS taps/scrolls to the host as xterm mouse events when the
        // remote app (tmux, vim, htop) requests mouse mode. SwiftTerm defaults
        // this to true, but we set it explicitly so future SwiftTerm releases
        // can't silently flip the default.
        view.allowMouseReporting = true

        // Replace SwiftTerm's default TerminalAccessory with our branded key
        // bar (matches DesignSystem; sticky ctrl modifier; arrow keys honor
        // application-cursor mode like SwiftTerm's default).
        view.inputAccessoryView = WTKeyBar(terminal: view)

        // 1) Suppress SwiftTerm's iOS long-press → context-menu when the host
        //    has mouse mode on. Otherwise a slow tap/drag in tmux pops the
        //    iOS Cut/Copy/Paste menu and (on iOS 16+) can auto-paste clipboard
        //    contents into the terminal.
        context.coordinator.installLongPressGuard(on: view)

        // 2) Two-finger pan → xterm mouse-wheel events. Lets tmux's
        //    "scroll wheel enters copy-mode" binding work on iPhone.
        context.coordinator.installTwoFingerWheelPan(on: view)

        // 3) Pinch-to-zoom font size. UIPinchGestureRecognizer on the
        //    UIKit view (not SwiftUI MagnifyGesture) so it targets the
        //    TerminalView directly and doesn't conflict with SwiftUI's
        //    gesture system.
        context.coordinator.installPinchZoom(on: view)

        context.coordinator.attach(view: view, inbound: inbound())
        return view
    }

    public func updateUIView(_ uiView: TerminalView, context: Context) {
        context.coordinator.applyFocusIfActive(uiView, isActive: isActive)
        context.coordinator.clampSwiftTermPanRecognizers(on: uiView)
        // Re-apply theme if it changed (e.g. user picked a new theme in settings).
        context.coordinator.applyThemeIfChanged(uiView, theme: theme)
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
        /// Gate outbound bytes during the initial handshake. SwiftTerm
        /// responds to DA1/DA2 queries from the server automatically; those
        /// responses must NOT be forwarded to the PTY because by the time
        /// they arrive the shell is in interactive mode and treats them as
        /// keyboard input. We suppress sends for the first ~500ms after
        /// the inbound pump starts.
        private var suppressSendUntil: Date = .distantFuture

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
            // Suppress DA1/DA2 response forwarding for the first 500ms.
            suppressSendUntil = Date().addingTimeInterval(0.5)
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
            // Suppress SwiftTerm's automatic DA1/DA2/DA3 responses during
            // the initial handshake window. These responses contain escape
            // sequences like ESC[?65;4;1;2;6;21;22;17;28c that the shell
            // echoes as literal text when they arrive too late.
            if Date() < suppressSendUntil {
                return
            }
            onSend(Data(data))
        }
        fileprivate func forwardResize(rows: Int, cols: Int) {
            onResize(rows, cols)
        }

        // MARK: - Auto-focus

        private var lastIsActive: Bool = false
        private var lastThemeID: String?
        private var focusTask: Task<Void, Never>?

        /// Become first responder when the host says this view is the active
        /// tab. Resign when it isn't. Called on every updateUIView so we react
        /// to TabView selection changes — without this, switching tabs in
        /// TerminalSessionsView leaves the previously-focused tab frozen
        /// (only one UIView can be first responder at a time).
        func applyFocusIfActive(_ view: TerminalView, isActive: Bool) {
            // Only act on transitions to avoid fighting user-driven keyboard
            // dismissal during a single active session.
            guard isActive != lastIsActive else { return }
            lastIsActive = isActive

            if isActive {
                focusTask?.cancel()
                focusTask = Task { @MainActor [weak view] in
                    for _ in 0..<30 { // up to ~1.5s for window-attach
                        guard let view else { return }
                        if view.window != nil {
                            _ = view.becomeFirstResponder()
                            return
                        }
                        try? await Task.sleep(nanoseconds: 50_000_000)
                    }
                }
            } else if view.isFirstResponder {
                _ = view.resignFirstResponder()
            }
        }

        // MARK: - Theme

        func applyThemeIfChanged(_ view: TerminalView, theme: TerminalTheme) {
            guard theme.id != lastThemeID else { return }
            lastThemeID = theme.id
            theme.apply(to: view)
        }

        // MARK: - Gesture customizations

        private var longPressGuard: LongPressGuard?
        private var wheelPanRecognizer: UIPanGestureRecognizer?
        private var wheelPanLastY: CGFloat = 0
        private var pinchRecognizer: UIPinchGestureRecognizer?
        private var pinchBaseFontSize: CGFloat = 14
        private static let minFontSize: CGFloat = 8
        private static let maxFontSize: CGFloat = 32
        @AppStorage("terminalFontSize") private var persistedFontSize: Double = 14

        /// Add a UIGestureRecognizerDelegate to ALL UILongPressGestureRecognizers
        /// that suppresses them whenever the remote terminal has mouse mode on.
        func installLongPressGuard(on view: TerminalView) {
            let guardDelegate = LongPressGuard(view: view)
            self.longPressGuard = guardDelegate
            for recognizer in view.gestureRecognizers ?? [] {
                if let lp = recognizer as? UILongPressGestureRecognizer {
                    lp.delegate = guardDelegate
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

        /// Pinch-to-zoom font size with persistence.
        func installPinchZoom(on view: TerminalView) {
            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            view.addGestureRecognizer(pinch)
            pinchRecognizer = pinch
            let saved = CGFloat(persistedFontSize)
            if abs(view.font.pointSize - saved) > 0.5 {
                view.font = UIFont.monospacedSystemFont(ofSize: saved, weight: .regular)
            }
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = self.view else { return }
            switch recognizer.state {
            case .began:
                pinchBaseFontSize = view.font.pointSize
            case .changed:
                let newSize = min(
                    Self.maxFontSize,
                    max(Self.minFontSize, pinchBaseFontSize * recognizer.scale)
                )
                let rounded = (newSize * 2).rounded() / 2
                if abs(view.font.pointSize - rounded) >= 0.5 {
                    view.font = UIFont.monospacedSystemFont(ofSize: rounded, weight: .regular)
                }
            case .ended, .cancelled:
                persistedFontSize = Double(view.font.pointSize)
            default:
                break
            }
        }

        /// Force every SwiftTerm-added UIPanGestureRecognizer to single-finger
        /// only, AND make it require our wheel pan to fail first.
        func clampSwiftTermPanRecognizers(on view: TerminalView) {
            guard let wheel = self.wheelPanRecognizer else { return }
            for recognizer in view.gestureRecognizers ?? [] {
                guard let pan = recognizer as? UIPanGestureRecognizer,
                      pan !== wheel,
                      pan !== view.panGestureRecognizer
                else { continue }
                if pan.maximumNumberOfTouches != 1 {
                    pan.maximumNumberOfTouches = 1
                }
                // Tell SwiftTerm's pan to wait for our wheel-pan to fail
                // before recognizing. Idempotent — UIKit dedupes.
                pan.require(toFail: wheel)
            }
        }

        @objc private func handleWheelPan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = self.view else { return }
            let terminal = view.getTerminal()
            guard terminal.mouseMode != .off else { return }

            switch recognizer.state {
            case .began:
                wheelPanLastY = recognizer.translation(in: view).y
            case .changed:
                // translation(in:) is cumulative since gesture start.
                let now = recognizer.translation(in: view).y
                let delta = now - wheelPanLastY
                let cellHeight = max(view.bounds.height / CGFloat(max(terminal.rows, 1)), 1)
                // Only emit when accumulated movement crosses a full cell.
                guard abs(delta) >= cellHeight else { return }
                let lines = Int(delta / cellHeight)
                if lines == 0 { return }
                // Advance the baseline by exactly the lines we consumed,
                // so leftover sub-cell movement carries into next tick.
                wheelPanLastY += CGFloat(lines) * cellHeight

                // iOS natural-scrolling convention: drag DOWN with fingers =
                // reveal content from ABOVE = wheel-UP (button 64).
                // Drag UP with fingers = reveal content from BELOW = wheel-DOWN (65).
                let wheelButton = lines > 0 ? 64 : 65
                let count = abs(lines)

                // Use the actual gesture location so the event lands inside
                // the active pane, not the status bar at row 0.
                let location = recognizer.location(in: view)
                let cols = max(terminal.cols, 1)
                let rows = max(terminal.rows, 1)
                let cellWidth = max(view.bounds.width / CGFloat(cols), 1)
                let col = max(0, min(cols - 1, Int(location.x / cellWidth)))
                let row = max(0, min(rows - 1, Int(location.y / cellHeight)))

                for _ in 0..<count {
                    terminal.sendEvent(buttonFlags: wheelButton, x: col, y: row)
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
            return view.getTerminal().mouseMode == .off
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
