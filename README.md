# Anvil

The ultimate native macOS agent harness / everything app — all features of Claude Code, Codex, and OpenCode, bigger, better UI, fully native Apple Swift + Xcode 27.

> Built from reverse-engineered lessons rebuilding Claude and Codex desktop apps (OpenClaudeCodexDesktop / RelayForge, System5, and others) plus the MIT-licensed OpenCode CLI (v2.2.5).

## What's in this repo

| Item | Purpose |
|------|---------|
| `SPEC.md` | Product spec: branding (Anvil), UI direction, feature set, hybrid-then-native engine strategy |
| `.referencedata/` | Reverse-engineered evidence: extracted OpenCode.app ASAR + opencode CLI source (ground truth to embed) |
| `Anvil.xcodeproj` / `Sources/` | Native Swift 6 + SwiftUI macOS app (Xcode 27) — scaffolded below |
| `Assets.xcassets` | App icon, theme graphics, branding |

## Build & run

```sh
cd /Volumes/Artificial_Intelligence_Machine_Learning/dev/OpenCodeNext
xcodebuild -scheme Anvil -configuration Debug
```

Open `Anvil.xcodeproj` in Xcode 27, select the **Anvil** scheme, run.

## Phases

1. **Hybrid (now):** SwiftUI shell + embedded OpenCode CLI server + native provider layer + Keychain + themes (Matrix included)
2. **Native engine:** Pure-Swift session engine replaces the CLI bridge incrementally
3. **Ship:** Sparkle auto-update, GitHub repo + Pages, notarized DMG
