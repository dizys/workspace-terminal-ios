# UX Design

## Screens

### Login

- URL field (with `.well-known/openid-configuration` + `/api/v2/users/authmethods` probe on commit).
- Probe result determines visible auth methods:
  - "Continue with `<OIDC provider name>`" → `ASWebAuthenticationSession`
  - "Continue with GitHub" (if Coder has GitHub OAuth enabled)
  - "Sign in with username & password" (only if password auth is enabled on the deployment)
- Custom CA upload step if TLS validation fails on URL probe.

### Workspace list (iPhone)

- `NavigationStack` root.
- Pull-to-refresh.
- Status badges: Running (green), Stopped (gray), Starting (blue, animated), Failed (red).
- Quick actions on swipe: Start / Stop / Open in Browser.
- Tap row → workspace detail.

### Workspace list (iPad)

- `NavigationSplitView` 3-column on iPad Pro 12.9", collapsing 2-column on iPad mini.
- Sidebar: deployments + workspace list.
- Content: workspace detail.
- Detail: terminal (full-bleed).

### Workspace detail

- Header: name, template, owner, status, last activity.
- Agents section: parent agent + child agents (one per running devcontainer). Each row shows agent name, OS/arch, status, "Open Terminal" CTA.
- Lifecycle controls: Start / Stop / Restart with confirmation.
- Build log expander when status is `Starting` or `Failed`.

### Terminal

- Full-bleed SwiftTerm view.
- Floating key bar above keyboard (auto-hides when hardware keyboard attached).
- Top bar: workspace name · agent name · connection status dot · tab strip (if >1 tab).
- Long-press top bar → quick actions (clear, reset, send Ctrl-C, disconnect).

### Settings

- Account: current deployment, switch deployment, sign out, "Add another deployment".
- Appearance: theme, font, font size, background opacity.
- Key bar: reorder, add/remove keys.
- Security: biometric gate, screen-recording blur, pasteboard expiry.
- Diagnostics: opt-in crash reporting (off by default), log export.
- About: version, license, privacy policy.

## Floating key bar

- Always-visible accessory above software keyboard.
- **Row 1**: Esc · Tab · `~` · `/` · `|` · `-` · arrows · Home/End · PgUp/PgDn
- **Row 2 (modifiers)**: Ctrl · Alt · Shift · Meta — sticky one-shot (latch on tap, release after next non-modifier; double-tap to lock).
- Long-press any key = repeat. Long-press arrow = jump-by-word.
- Swipe horizontally to reveal F-keys (F1–F12).
- Reorderable in Settings → Key bar.
- Auto-hide when hardware keyboard attached.

## Touch interactions in terminal

| Gesture | Action |
|---|---|
| Single tap empty area | Toggle keyboard |
| Two-finger pan | Scrollback |
| Pinch | Font size (clamped 9–24pt; haptic at min/max) |
| Long-press | Enter selection mode with iOS magnifier loupe; copy/paste via system menu |
| Drag from key bar to text | Insert literal char (e.g. literal `Esc`) |
| Three-finger swipe left/right (iPad) | Switch tab |

## Hardware keyboard (iPad-critical)

- Full `UIKey` event support: modifiers + arrows + function keys + Globe.
- `UIKeyCommand` menu (visible via hold-Cmd overlay):
  - `Cmd-T` new tab
  - `Cmd-W` close tab
  - `Cmd-N` new window (iPad)
  - `Cmd-K` clear scrollback
  - `Cmd-+` / `Cmd--` font size
  - `Cmd-1` … `Cmd-9` switch to tab N
  - `Cmd-Shift-[` / `Cmd-Shift-]` previous/next tab
  - `Cmd-,` settings
  - `Cmd-Shift-D` switch deployment
- On iPad with hardware keyboard, **floating key bar auto-hides** (user has Esc/Tab/arrows on the physical keyboard).

## iPad-specific polish

- **Multi-window** via `UIWindowSceneDelegate` + `Scene` — drag a workspace into its own window; split-screen two terminals side-by-side.
- **Stage Manager** + external display — terminal scales gracefully on external monitors.
- **Pointer support**: hover states for buttons, scroll wheel routes to scrollback, click-drag selection.
- **Drag & drop**: drag selected text out of the terminal into another iPad app; drop text in to paste.

## Theming

- Bundle **JetBrains Mono Nerd Font** (Powerline + dev icons; ligatures off by default for terminals).
- Themes: System (matches iOS appearance), Tokyo Night, Catppuccin Mocha/Latte, Solarized Light/Dark, Dracula, Gruvbox, custom JSON import.
- Background opacity slider (semi-transparent over wallpaper for personality on iPad).

## Accessibility

- VoiceOver pass on every non-terminal screen (terminal itself is text-canvas; expose status + selected text via accessibility API).
- Dynamic Type respected for non-terminal UI; terminal font has its own setting.
- Reduce Motion respected (kill animated status badges).
- Sufficient contrast in all themes (WCAG AA at minimum).
