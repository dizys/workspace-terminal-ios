# Open Questions

Decisions still pending. Resolve before the relevant milestone.

## Pricing model (resolve before M0 ends)

Two options:

1. **One-time purchase** — e.g. $14.99. Simple, no server, no subscription complexity. Faster to ship. No recurring revenue.
2. **Subscription** — e.g. $2.99/mo, $24.99/yr. Recurring revenue. Requires receipt validation infra and a "free vs paid" UX decision.

**Current lean:** one-time purchase for v1. Add an optional Pro subscription later if/when we ship cloud-sync features (themes/settings sync, multi-device session resume).

## App identifier and name (resolve before M5)

- Bundle ID: `app.coderterminal.ios` (placeholder, in use until decided otherwise)
- Name: "Coder Terminal"? "Codex Terminal"? "Coder for iOS"? Coordinate with Coder Inc. on trademark before publishing.

## Coder Inc. relationship (resolve before M5)

Not affiliated with Coder Inc. by default. Options:

- **Pure third-party** — no coordination, just clearly state "unofficial" in App Store description.
- **Reach out for blessing** — DM their team on Discord, get informal "we're cool with it" before launch. Reduces trademark risk.
- **Partnership** — too ambitious for v1; revisit if traction warrants.

**Current lean:** reach out for informal blessing before App Store submission.

## Theme JSON format (resolve before M3)

Adopt an existing format or invent one?

- **iTerm2 .itermcolors** (XML plist) — huge ecosystem of themes, but XML.
- **Alacritty theme TOML** — clean, modern, smaller ecosystem.
- **Custom JSON** — full control, no ecosystem.

**Current lean:** support both iTerm2 import and Alacritty TOML import; native format is JSON.

## Shortcuts / App Intents (post-v1?)

iOS Shortcuts integration would let users automate "open my dev workspace at 9am". Worth considering for v1 polish, but not committed.

## Background notifications (post-v1?)

Notify when a workspace finishes building, or when a stopped workspace is auto-deleted. Requires push infrastructure → adds server-side complexity. Defer.
