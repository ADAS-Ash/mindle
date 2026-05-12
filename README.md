<p align="center">
  <img src="assets/logo.svg" width="128" height="128" alt="Mindle logo">
</p>

<h1 align="center">Mindle</h1>

<p align="center">
  <em>A quiet place to read Markdown.</em>
</p>

<p align="center">
  <a href="https://nonatofabio.github.io/mindle/"><strong>Website</strong></a> &bull;
  <a href="#install">Install</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#agent-collaboration">Agents</a> &bull;
  <a href="#keyboard-shortcuts">Shortcuts</a> &bull;
  <a href="#build-from-source">Build</a> &bull;
  <a href="#roadmap">Roadmap</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue?style=flat-square" alt="macOS 14+">
  <img src="https://img.shields.io/badge/swift-6.x-orange?style=flat-square" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-MIT%20%2B%20Commons%20Clause-blue?style=flat-square" alt="MIT + Commons Clause (v2.0+)">
  <img src="https://img.shields.io/github/actions/workflow/status/nonatofabio/mindle/build.yml?style=flat-square&label=build" alt="Build status">
  <img src="https://img.shields.io/github/downloads/nonatofabio/mindle/total?style=flat-square&label=downloads" alt="Total downloads">
</p>

---

**Mindle** is a native macOS Markdown reader built for focused, distraction-free reading. Think of it as a personal e-reader for your `.md` files — serif typography, warm themes, and the ability to highlight and annotate passages without ever leaving the document.

Since v2.0, Mindle also speaks MCP. When you're collaborating with an AI agent on a document, your annotations become a back-and-forth channel anchored to the passage — you mark up, the agent picks up the event, addresses it, replies inline in the thread. The conversation lives in the file, not in a chat window.

No Electron. No subscriptions. No telemetry. The auto-update check is the only network call, and it's opt-in.

## Install

### Download (recommended)

Grab the latest `Mindle.dmg` from [**Releases**](https://github.com/nonatofabio/mindle/releases), open it, and drag **Mindle** into **Applications**. Signed with a Developer ID and notarized by Apple — no Gatekeeper prompt, no terminal commands.

### Build from source

```bash
git clone https://github.com/nonatofabio/mindle.git
cd mindle
./build.sh
open build/Mindle.app
```

Requires **macOS 14+** and **Xcode Command Line Tools** (`xcode-select --install`).

## Features

### Reading
- **Full GitHub-Flavored Markdown** — tables, task lists, footnotes, strikethrough, syntax-highlighted code, emoji, nested lists, raw HTML. Powered by [markdown-it](https://github.com/markdown-it/markdown-it) + [highlight.js](https://highlightjs.org).
- **LaTeX math** — inline (`$a^2 + b^2 = c^2$`) and display (`$$ \int e^{-x^2} dx = \sqrt{\pi} $$`) blocks rendered with [KaTeX](https://katex.org), bundled locally.
- **Mermaid diagrams** — flowcharts, sequence diagrams, and the rest, rendered inline. Click to expand.
- **Images** — relative, absolute, `file://`, and `data:` URLs all resolve. Remote `http(s)` is blocked — no tracking pixels.
- **YAML frontmatter** — files like `SKILLS.md` show their `---`-delimited block as a syntax-highlighted code fence instead of two horizontal rules around plain text.
- **Three themes** — Light, Sepia, Dark. Cycle with `⌘⇧T`.
- **Typography controls** — scale the serif reading font with `⌘+` / `⌘-`.

### Workflow
- **Tabs and multi-window** — open many files in one window (`⌘O` adds a tab) or pop a new window with `⌘N`. `⌘W` closes the active tab when more than one is open, otherwise the window.
- **File browser** — scoped sidebar tree of every `.md` and `.txt` in the current folder (`⌘⇧F`). Never escapes upward.
- **Find in document** — live search with match count, `⌘F` / `⌘G` / `⌘⇧G`.
- **Live reload** — external edits (vim, an agent, Dropbox, anything) re-render automatically. Bursty writes are debounced; scroll position is preserved.
- **Diff-on-reload** — when an external write changes the active file, Mindle renders the change as a Word-style track-changes overlay you can ✓ Keep or ✗ Revert per chunk, or whole-document with `⌘⌥⏎` / `⌘⌥⌫`.
- **PDF export** — `⌘P` produces a paginated Letter-sized PDF with print-styled typography.
- **Auto-update** — opt-in, off by default. EdDSA-verified binaries via [Sparkle](https://sparkle-project.org).

### Annotation
- **Highlight & note** — select any passage, press `⌘⇧H` to highlight or `⌘⇧N` to attach a note. Works across paragraphs, headings, lists, and code blocks.
- **Annotations sidebar** — toggle with `⌘⇧A`. Click any annotation to jump to its passage; notes are editable inline. The new card auto-scrolls into view.
- **Threads** — each annotation carries a conversation. You and the agent can reply back and forth in a single-column transcript with author-keyed left stripes (gray for the agent, accent for you). Return commits a reply; Shift+Return inserts a newline.
- **Persistent locally** — saved to a hidden `.yourfile.md.mindle.json` sidecar. Nothing leaves your machine.
- **Export** — `⌘⇧E` exports highlights and notes as Markdown or JSON.

### Agent collaboration (new in v2.0)
- **Read-side parity** — an agent can list every file you have open in Mindle and read your annotations on each. Selection text and surrounding context arrive verbatim, so the agent knows exactly what you're pointing at.
- **Write-side affordances** — the agent can post comments to a thread, open a fresh annotation on a passage ("does this read better?"), and dismiss its own annotations with a one-line summary. Agent-authored annotations are visually distinct (muted dot, "Agent" label).
- **Ambient watch loop** — a long-polling tool lets the agent wait for your next annotation or thread reply. You annotate, the agent wakes within a second, addresses it, waits again. Pure MCP, so any compatible client (Claude Code, Codex, Cursor, custom) can drive the loop.
- **Self-filtering** — the agent's own mutations never wake itself. Each helper process gets a per-launch UUID; events tagged with that UUID are filtered out of its own watch responses.

See [Agent Collaboration](#agent-collaboration) below for setup.

### Plumbing
- **Native Swift / SwiftUI** — no Electron. Single-binary app, no frameworks to install at runtime.
- **Local-only by default** — auto-update is the lone network feature, opt-in.
- **Signed and notarized** — Developer ID + Apple notarization on every release.

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘O` | Open a file (adds a tab if a window is open) |
| `⌘N` | New window |
| `⌘W` | Close active tab (or window, when only one tab is open) |
| `⌘F` | Find in document |
| `⌘G` / `⌘⇧G` | Next / previous match |
| `⌘P` | Export as PDF |
| `⌘⇧E` | Export annotations (Markdown or JSON) |
| `⌘⇧H` | Highlight selection |
| `⌘⇧N` | Add note to selection |
| `⌘⇧A` | Toggle annotations sidebar |
| `⌘⇧F` | Toggle files sidebar |
| `⌘⇧T` | Cycle theme (light / sepia / dark) |
| `⌘+` / `⌘-` | Increase / decrease font size |
| `⌘⌥⏎` | Keep all in-flight changes |
| `⌘⌥⌫` | Revert all in-flight changes |
| `Return` (in annotation editor) | Commit the note / reply |
| `⇧Return` (in annotation editor) | Insert a newline |

## Agent Collaboration

Mindle ships an MCP (Model Context Protocol) server so an agent can read your open files, see your annotations, and join the conversation. The collaboration loop is the headline v2.0 feature; everything below is optional but rewarding.

### Setup with Claude Code

```bash
claude mcp add mindle /Applications/Mindle.app/Contents/MacOS/mindle-mcp
```

Restart Claude Code so it handshakes the new server, then ask:

> watch my Mindle annotations and answer them

The agent calls `wait_for_annotation_event` in a loop. You annotate (`⌘⇧N` for a note, then type, then Return); the agent wakes within a second, reads the surrounding context, and posts a reply in the thread or edits the file and clears the annotation.

Any MCP-aware client works the same way — the tool descriptions carry enough protocol guidance that vanilla agents run the loop without a custom skill.

### Tools exposed

| Tool | Direction | What it does |
|------|-----------|--------------|
| `list_open_files` | read | Every file open in any Mindle window |
| `get_annotations(path)` | read | Annotations + threads on a file |
| `comment_on_annotation(path, id, text)` | write | Append an agent message to a thread |
| `create_annotation(path, text, prefix, suffix, note)` | write | Open an agent-authored annotation on a passage |
| `clear_annotation(path, id, summary)` | write | Mark an annotation done with a summary |
| `wait_for_annotation_event(timeout_seconds, since_event_id)` | read | Long-poll for the next user event (created / thread reply / deleted) |

The server is read-only as far as the file system is concerned — file IO stays in the agent's own tools. Mindle exposes only the annotation channel.

## Architecture

```
SwiftUI shell (window, tabs, toolbar, theme + font + diff state)
  ├── DocumentStore (per window) ── FSEvents file watcher
  └── WKWebView (reader pane)
        ├── markdown-it     → Markdown → HTML (+ task-lists, footnote, anchor)
        ├── highlight.js    → syntax coloring
        ├── KaTeX           → inline + display math
        ├── mermaid         → diagrams (click to expand)
        ├── jsdiff          → diff-on-reload chunks
        └── reader.js       → unified applyAll() pipeline:
                              annotation overlays, search marks,
                              diff render, scroll preservation
```

Annotations use a **text + context** anchoring strategy (inspired by [Hypothes.is](https://web.hypothes.is/)): each highlight stores the selected text plus 48 chars of prefix/suffix. This means highlights survive minor edits to the source file — and is what makes diff-on-reload's accept/reject loop coherent: annotations re-anchor against the new text instead of going stale.

## Roadmap

The big-picture plan lives in [`docs/v2-roadmap.md`](docs/v2-roadmap.md). Where we are:

**Shipped**

- ✅ **v2.0 — MCP collaboration loop.** Mindle is the review surface for agent-driven markdown work. The agent writes, you mark up; the agent reads your annotations and threads back, replies inline, or addresses them by editing the file. See [Agent Collaboration](#agent-collaboration).

**Next**

- **v2.1 — Multi-user collaboration foundation.** Identity, author-stamped annotations, diff-banner attribution, and cloud-drive folder detection. A colleague editing your file in iCloud / OneDrive / Dropbox becomes architecturally indistinguishable from an agent — Mindle just makes you see them. No new sync code; the cloud drive is the transport.
- **v2.2 — Bring-your-own sync (S3 first).** A `SyncProvider` protocol with an S3 backend for teams whose markdown lives in a bucket. ETag-based optimistic concurrency, conflicts surfaced through the same diff-on-reload UX.

**Eventually**

- **Homebrew cask** — `brew install --cask mindle` for one-line install.
- **iOS / iPadOS port** — multiplatform build sharing the same WebKit reader and annotation engine.

## License

Mindle **v2.0 and later** is licensed under [**MIT + Commons Clause**](LICENSE). Use it, fork it, modify it, embed it in your own work — same MIT freedoms you'd expect — with one added condition: you may not *Sell* the Software (or sell hosting / support / services whose value derives substantially from it) without a separate commercial agreement. For commercial licensing inquiries, please get in touch.

Versions **v1.x** were released under the pure [MIT License](https://opensource.org/license/mit/) and remain available under those terms in the corresponding v1.x release tags.
