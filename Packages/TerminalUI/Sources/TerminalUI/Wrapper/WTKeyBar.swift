#if os(iOS) || os(visionOS)
import DesignSystem
import SwiftTerm
import UIKit

/// Branded key bar that replaces SwiftTerm's default `TerminalAccessory`.
///
/// Renders a horizontally scrollable row of keys (esc, tab, ctrl, arrows, and
/// common shell punctuation) with our design tokens. `ctrl` is a sticky
/// one-shot modifier — tap once, the next keystroke from the on-screen
/// keyboard is sent as control+key, then ctrl resets.
///
/// Hosting: assign to `TerminalView.inputAccessoryView`. UIKit positions the
/// view above the system keyboard automatically; height comes from the
/// intrinsic content size.
@MainActor
final class WTKeyBar: UIInputView {
    private weak var terminal: TerminalView?
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private var ctrlButton: KeyButton?

    init(terminal: TerminalView) {
        self.terminal = terminal
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 44),
                   inputViewStyle: .keyboard)
        translatesAutoresizingMaskIntoConstraints = false
        allowsSelfSizing = true
        configure()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 44)
    }

    private func configure() {
        backgroundColor = UIColor(WTColor.surface)

        let topBorder = UIView()
        topBorder.backgroundColor = UIColor(WTColor.border)
        topBorder.translatesAutoresizingMaskIntoConstraints = false
        addSubview(topBorder)

        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.alwaysBounceHorizontal = true
        addSubview(scroll)

        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.distribution = .fill
        scroll.addSubview(stack)

        for definition in WTKeyBar.defaultKeys {
            let button = KeyButton(definition: definition) { [weak self] in
                self?.handleTap(definition)
            }
            if case .ctrl = definition.action { ctrlButton = button }
            stack.addArrangedSubview(button)
        }

        NSLayoutConstraint.activate([
            topBorder.topAnchor.constraint(equalTo: topAnchor),
            topBorder.leadingAnchor.constraint(equalTo: leadingAnchor),
            topBorder.trailingAnchor.constraint(equalTo: trailingAnchor),
            topBorder.heightAnchor.constraint(equalToConstant: 0.5),

            scroll.topAnchor.constraint(equalTo: topBorder.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.topAnchor.constraint(equalTo: scroll.topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor, constant: -6),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor, constant: -12),
        ])
    }

    // MARK: - Key handling

    private func handleTap(_ definition: KeyDefinition) {
        guard let terminal else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        switch definition.action {
        case .ctrl:
            terminal.controlModifier.toggle()
            ctrlButton?.setSelected(terminal.controlModifier)
        case .escape:
            terminal.send(data: [0x1B][...])
        case .tab:
            terminal.send(data: [0x09][...])
        case .up:
            terminal.send(data: terminal.getTerminal().applicationCursor
                          ? EscapeSequences.moveUpApp[...]
                          : EscapeSequences.moveUpNormal[...])
        case .down:
            terminal.send(data: terminal.getTerminal().applicationCursor
                          ? EscapeSequences.moveDownApp[...]
                          : EscapeSequences.moveDownNormal[...])
        case .left:
            terminal.send(data: terminal.getTerminal().applicationCursor
                          ? EscapeSequences.moveLeftApp[...]
                          : EscapeSequences.moveLeftNormal[...])
        case .right:
            terminal.send(data: terminal.getTerminal().applicationCursor
                          ? EscapeSequences.moveRightApp[...]
                          : EscapeSequences.moveRightNormal[...])
        case .literal(let text):
            terminal.send(txt: text)
        }
    }

    // MARK: - Key catalog

    private struct KeyDefinition {
        let label: String
        let action: KeyAction
        let style: KeyButton.Style
    }

    private enum KeyAction {
        case ctrl
        case escape
        case tab
        case up, down, left, right
        case literal(String)
    }

    private static let defaultKeys: [KeyDefinition] = [
        .init(label: "esc",  action: .escape,        style: .modifier),
        .init(label: "ctrl", action: .ctrl,          style: .modifier),
        .init(label: "tab",  action: .tab,           style: .modifier),
        .init(label: "~",    action: .literal("~"),  style: .key),
        .init(label: "/",    action: .literal("/"),  style: .key),
        .init(label: "|",    action: .literal("|"),  style: .key),
        .init(label: "-",    action: .literal("-"),  style: .key),
        .init(label: "↑",    action: .up,            style: .arrow),
        .init(label: "↓",    action: .down,          style: .arrow),
        .init(label: "←",    action: .left,          style: .arrow),
        .init(label: "→",    action: .right,         style: .arrow),
    ]

    // MARK: - KeyButton

    @MainActor
    final class KeyButton: UIControl {
        enum Style { case key, modifier, arrow }

        private let label = UILabel()
        private let backing = UIView()
        private let style: Style
        private let onTap: () -> Void
        private var isSelectedState: Bool = false

        init(definition: WTKeyBar.KeyDefinition, onTap: @escaping () -> Void) {
            self.style = definition.style
            self.onTap = onTap
            super.init(frame: .zero)
            translatesAutoresizingMaskIntoConstraints = false

            backing.translatesAutoresizingMaskIntoConstraints = false
            backing.layer.cornerRadius = 6
            backing.layer.cornerCurve = .continuous
            backing.isUserInteractionEnabled = false
            addSubview(backing)

            label.translatesAutoresizingMaskIntoConstraints = false
            label.text = definition.label
            label.textAlignment = .center
            label.font = UIFont.monospacedSystemFont(ofSize: 15, weight: .medium)
            label.isUserInteractionEnabled = false
            backing.addSubview(label)

            NSLayoutConstraint.activate([
                backing.topAnchor.constraint(equalTo: topAnchor),
                backing.bottomAnchor.constraint(equalTo: bottomAnchor),
                backing.leadingAnchor.constraint(equalTo: leadingAnchor),
                backing.trailingAnchor.constraint(equalTo: trailingAnchor),

                label.centerYAnchor.constraint(equalTo: backing.centerYAnchor),
                label.leadingAnchor.constraint(equalTo: backing.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: backing.trailingAnchor, constant: -12),
                heightAnchor.constraint(greaterThanOrEqualToConstant: 32),
                widthAnchor.constraint(greaterThanOrEqualToConstant: 38),
            ])

            addTarget(self, action: #selector(handleTouchUpInside), for: .touchUpInside)
            addTarget(self, action: #selector(handleTouchDown), for: .touchDown)
            addTarget(self, action: #selector(handleTouchUpOutside), for: [.touchUpOutside, .touchCancel])

            applyVisualState()
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) not used") }

        func setSelected(_ value: Bool) {
            isSelectedState = value
            applyVisualState()
        }

        private func applyVisualState() {
            let isPressed = isHighlighted
            let isOn = isSelectedState
            switch style {
            case .key:
                backing.backgroundColor = isPressed
                    ? UIColor(WTColor.surfaceElevated)
                    : UIColor(WTColor.surface)
                label.textColor = UIColor(WTColor.textPrimary)
            case .modifier:
                backing.backgroundColor = isOn
                    ? UIColor(WTColor.accent)
                    : isPressed
                        ? UIColor(WTColor.surfaceElevated)
                        : UIColor(WTColor.surface)
                label.textColor = isOn
                    ? UIColor(WTColor.background)
                    : UIColor(WTColor.textSecondary)
            case .arrow:
                backing.backgroundColor = isPressed
                    ? UIColor(WTColor.accent.opacity(0.4))
                    : UIColor(WTColor.accent.opacity(0.18))
                label.textColor = UIColor(WTColor.accent)
            }
            backing.layer.borderWidth = 0.5
            backing.layer.borderColor = UIColor(WTColor.border).cgColor
        }

        @objc private func handleTouchDown() { applyVisualState() }
        @objc private func handleTouchUpOutside() { applyVisualState() }
        @objc private func handleTouchUpInside() {
            applyVisualState()
            onTap()
        }
    }
}
#endif
