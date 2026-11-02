# Anvil — Ultimate Native Agent Harness

**Repo dir:** `OpenCodeNext` (kept as-is)  
**Product name / bundle:** Anvil / `ai.anvil.desktop`  
**Framework:** Native macOS, Swift 6 + SwiftUI, Xcode 27, macOS 27 SDK  
**Deployment target:** macOS 26 / 27  
**Engine strategy:** Hybrid now → full native engine later. Hybrid core wraps the MIT-licensed OpenCode CLI server (v2.2.5 source checked in `.referencedata/opencode-cli`) over its native IPC/HTTP, and Anvil adds its own provider layer, session UI, tool approvals, and native Apple Intelligence / Core ML paths. A pure-Swift session engine replaces it incrementally.

## Why the name Anvil

- One crisp word; badge-scale icon (raised anvil, iron + code glyph)
- Distinct from OpenCode/Claude/Codex/RelayForge/System5 — zero trademark collision risk
- Suggests "forging code," agents at work, durable native craft

## Design direction (per user decisions)

- **Default look:** Claude-code warm minimal + Codex navigation + OpenCode terminal heritage
- **Themes (shipped at once):** Warm minimal, Graphite (dark mono), Terminal heritage (near-black + bright accents), Matrix-inspired "techy" (dark + falling green glyph glyphs as ambient chrome, fast terminal scanlines, CRT phosphor option)
- **Unique title colors, themes, branding, app icon, graphics assets**
- **URL scheme:** `anvil://`
- **Bundle identifiers:** `ai.anvil.desktop` (prod), `.beta`, `.dev`

## Scope — "everything app" feature set

Parity with Claude Code + Codex + OpenCode desktop, plus native macOS integration:

| Domain | Features |
|--------|----------|
| Sessions | Multiple concurrent chats, per-session model/provider, chat list sidebar, search history, SwiftData persistence |
| Providers | OpenCode (bundled server), OpenAI, Anthropic, OpenRouter, NVIDIA NIM, Google Gemini, Apple Foundation Models, Ollama/LM Studio (local), custom OpenAI-compatible endpoints; API keys in Keychain |
| Models | Model picker w/ free-only filter, local/tool/reasoning/vision tags, context-size + price + release-date sort, Big-Pickle-style catalog |
| Chat | Streaming text + tool-call fragments, tool rounds (4) + synthesis, stop/cancel, approval dialog per tool call (server/tool/args, denial → tool error) |
| Artifacts | Rendered artifacts with version history + export (Codex-inspired), code blocks, tables, images |
| Terminal | Native PTY (node-pty-equivalent via SwiftProcess / `posix_spawn`), inline terminal pane, copy-paste, scrollback |
| Git | Libgit2-backed repo browser, diff view, commit, stage/unstage, blame-lite |
| Files | Native file indexing + search (SwiftData + `NSMetadataQuery`), file tree, quick-open |
| Browser | Embedded WebKit browser automation + Computer Use (AX-based screen driving) |
| MCP | Scan local Claude/Codex/OpenCode catalogs, activate MCP servers (local-command + HTTP), embedded loopback MCP endpoint `http://127.0.0.1:8765/mcp`, OAuth not auto-copied |
| Skills/Plugins | Catalog local skills & plugins; expose via embedded MCP server (`app_list_skills`, `app_read_skill`, `app_list_plugins`) |
| GitHub | Repo browsing, issues, PRs, Pages deploy, releases (from Settings) |
| Settings | Provider config, model catalog, keys (Keychain), themes, auto-update (Sparkle), signing |
| Auto-update | Sparkle appcast, self-hosted or GitHub releases |

## Guardrails

- No harness-based guardrails. Requests pass directly to the selected model; only model-imposed refusals. No refusal injection, no safety layers beyond the model.

## Architecture (Swift)

```
App (SwiftUI + AppKit bridge)
├── SessionStore (SwiftData)           — chats, messages, tool-call fragments
├── ProviderRegistry                   — OpenAI-compatible + native provider adapters
├── OpenCodeBridge                     — embedded opencode CLI server (hybrid phase 1)
├── PTYTerminal                        — native pseudo-terminal pane
├── MCPClient                          — SSE/streamable-HTTP + local-command JSON-RPC
├── EmbeddedMCPServer                  — loopback :8765/mcp
├── GitClient                          — libgit2 (Swift) or shell-out to git
├── FileIndex                          — NSMetadataQuery + SwiftData FTS
├── WebKitBrowser / ComputerUse        — embedded browser + AX driving
├── KeychainStore                      — SecItem API keys
├── ThemeEngine                        — 4 themes, dynamic accent color
└── UpdateManager                      — Sparkle
```

## Concurrency & quality discipline (System5 lessons, adopted)

- Single source of truth for providers (engine `/backends`-equivalent), no duplicated provider lists
- `Bundle.module`-based resource locator; no hardcoded paths
- Actors / `@MainActor` isolation; no `nonisolated(unsafe)` statics; proper `Task` cancellation
- Structured error types + error queue + consistent retry policy; never swallow into single error slot
- Generic `ModelManager` for download/cancel/delete + progress (one impl, not three)
- XCTest targets for Models, Services, Bridge modules (not just resource layout tests)
- No secrets in repo; keys from Keychain/env/Settings only

## References (reverse-engineered evidence)

- `/Applications/OpenCode.app` (v2.2.5) — Electron + Bun, ASAR extracted to `.referencedata/opencode-app-asar-extract` (11,807 files), bundle `ai.opencode.desktop`, `opencode://` scheme, `node:sqlite` + `node-pty` + Effect-TS runtime
- GitHub `anomalyco/opencode` v2.2.5 — checked into `.referencedata/opencode-cli` (ground-truth CLI/server source to embed in hybrid phase 1)
- `OpenClaudeCodexDesktop` (RelayForge) — provider matrix, MCP hub, embedded loopback MCP server, keychain creds, model picker w/ Free filter
- `System5` — Swift engine port, SwiftUI app, concurrency/testing pitfalls to avoid
