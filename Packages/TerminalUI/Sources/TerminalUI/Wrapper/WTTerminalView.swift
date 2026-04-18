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
        context.coordinator.attach(view: view, inbound: inbound())
        return view
    }

    public func updateUIView(_ uiView: TerminalView, context: Context) {
        // No-op for now; future: theme changes propagate here.
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
            view?.feed(byteArray: ArraySlice(chunk))
        }

        func dismantle() {
            pumpTask?.cancel()
            pumpTask = nil
            view = nil
        }

        // Bridges from the delegate-conformance extension into the Coordinator's
        // private callback closures.
        fileprivate func forwardSend(data: ArraySlice<UInt8>) {
            onSend(Data(data))
        }
        fileprivate func forwardResize(rows: Int, cols: Int) {
            onResize(rows, cols)
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
