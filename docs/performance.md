# Performance Budget

## Targets

| Metric | Target | Measurement |
|---|---|---|
| Cold launch → workspace list visible | <1.5s on iPhone 13 | XCTest launch metric |
| Tap workspace → connected PTY (warm) | <800ms | XCTest signpost |
| Tap workspace → connected PTY (cold) | <2s | XCTest signpost |
| Keypress → glyph on screen | <16ms (single 60Hz frame) | Instruments os_signpost |
| Scrollback scroll | 120fps on ProMotion | Instruments Animation Hitches |
| Memory steady-state idle terminal | <150MB | Instruments Allocations |
| Memory with 10k-line scrollback | <250MB | Instruments Allocations |
| Energy impact (idle session, 5min) | "Low" | Xcode Energy gauge |

## Strategies

- Profile early. Instruments Time Profiler + Allocations + Network from M2 onward, not at the end.
- SwiftTerm is GPU-accelerated; avoid wrapping it in SwiftUI in a way that breaks its rendering invariants. Use `UIViewRepresentable` directly, no extra layers.
- TCA effects for PTY are long-lived `.run` blocks — they bridge `AsyncStream` → actions in batches (not one action per byte). Batch on a 16ms tick to avoid action storms.
- Scrollback storage: ring buffer with byte cap (default 1MB per tab, configurable up to 10MB). When cap is hit, drop oldest lines.
- Image protocol / sixel: lazy-decode, cap rendered area.
- Background WebSocket: rely on iOS background URLSession only for short reconnect window (~30s), not indefinitely. iOS will kill long-lived background sockets anyway.

## Anti-patterns to avoid

- Don't put SwiftTerm inside `ScrollView` — it has its own scrollback. Wrapping it doubles the rendering and breaks gestures.
- Don't allocate per-byte. PTY input arrives in chunks; pass them through as `Data` slices.
- Don't synchronously decode UTF-8 on the main thread for large pastes. Move decode to a background task.
- Don't observe `URLSession.shared.dataTask` results on main; use the async API and `Task` continuations.
