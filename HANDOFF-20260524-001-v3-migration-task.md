# Task: Migrate Mindle to MarkCollab v3 Schema

## Metadata
```yaml
id: HANDOFF-20260524-001
created: 2026-05-24T09:46:00Z
status: PENDING
priority: high
fork_type: handoff
owner_current: kiro
owner_next: quick
provenance:
  created_by: qd
  session: qd-f2c578d4-c90d-48c8-9181-9c7bcfc969ba
```

## TL;DR
Update Mindle's Swift `Annotation` model and sidecar serialization to use the new MarkCollab v3 schema (W3C TextQuoteSelector alignment). Must read both v2 and v3 sidecars but only write v3.

---

## Context
We've upgraded the MarkCollab sidecar format from v2 to v3. Key changes:
- `anchor.text/prefix/suffix` → `selector` object with `type: "TextQuoteSelector"` + `exact/prefix/suffix`
- Added optional `TextPositionSelector` (start/end offsets)
- `selector` can be an array (composite selectors), a single object, or `null` (document-level annotations)
- Added `motivation` field on Annotation (enum: commenting, questioning, suggesting, highlighting, assessing, tagging)
- Added `type` field on ThreadMessage (enum: comment, resolution, reopen, assignment; default: comment)
- Version bumped from "2.0" → "3.0"

The v3 schema is at: `/Users/apnaik/Projects/markcollab-standalone/schema/collab.v3.schema.json`
The migration guide is at: `/Users/apnaik/Projects/markcollab-standalone/docs/migration-v2-to-v3.md`
The updated schema docs: `/Users/apnaik/Projects/markcollab-standalone/docs/schema.md`
The updated anchoring algorithm: `/Users/apnaik/Projects/markcollab-standalone/docs/anchoring.md`

Mindle source: `/Users/apnaik/Projects/markcollab/Sources/mindle/`

## Your Task

### Step 1: Update `Annotation` struct (DocumentStore.swift:24)

Current:
```swift
struct Annotation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String        // the selected passage verbatim
    var prefix: String      // ~32 chars before
    var suffix: String      // ~32 chars after
    var note: String
    ...
}
```

New — add a `Selector` enum and refactor:
```swift
enum SelectorType: String, Codable {
    case textQuote = "TextQuoteSelector"
    case textPosition = "TextPositionSelector"
}

struct TextQuoteSelector: Codable, Equatable {
    var type: SelectorType = .textQuote
    var exact: String
    var prefix: String
    var suffix: String
}

struct TextPositionSelector: Codable, Equatable {
    var type: SelectorType = .textPosition
    var start: Int
    var end: Int
}

enum Selector: Codable, Equatable {
    case quote(TextQuoteSelector)
    case position(TextPositionSelector)
    case composite([Selector])
    case none  // document-level
}

struct Annotation: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var selector: Selector
    var note: String
    var motivation: String?  // "commenting", "questioning", etc.
    ...existing fields...
}
```

Keep the existing `text`/`prefix`/`suffix` as **computed properties** that delegate to the selector, so the rest of the codebase (WebReaderView, ContentView, MCPServer) doesn't need immediate rewriting:
```swift
extension Annotation {
    var text: String { /* extract from selector.quote.exact */ }
    var prefix: String { /* extract from selector.quote.prefix */ }
    var suffix: String { /* extract from selector.quote.suffix */ }
}
```

### Step 2: Update `ThreadMessage` (DocumentStore.swift:14)

Add optional `type` field:
```swift
struct AnnotationMessage: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var author: String
    var text: String
    var type: String?  // "comment" (default), "resolution", "reopen", "assignment"
    var createdAt: Date = Date()
}
```

### Step 2b: Add Reactions support

Add a `Reaction` struct and optional `reactions` field to both `Annotation` and `AnnotationMessage`:

```swift
struct Reaction: Codable, Equatable {
    var emoji: String       // "👍", "🎯", "+1", "❤️"
    var authors: [String]   // collaborator aliases
}
```

- Add `var reactions: [Reaction]?` to both `Annotation` and `AnnotationMessage`
- When encoding: omit if nil/empty (keep JSON minimal)
- When decoding: treat missing field as nil (backward compat with existing sidecars)
- Note: Mindle already has a reaction picker UI (from the v2.2.4 upstream merge) — wire it to this data model

### Step 3: Update `Sidecar` serialization (DocumentStore.swift:953+)

The `Sidecar` struct and `loadSidecar()`/`writeSidecar()` need:

1. Add `version` field to Sidecar struct
2. **On write**: Always output v3 format (`"version": "3.0"`, annotations with `selector` object)
3. **On read**: Detect version and handle both:
   - If `version == "2.0"` or missing: map `anchor.text` → `selector.exact` etc. during decode
   - If `version == "3.0"`: decode directly

Use custom `init(from decoder:)` on Annotation to handle both formats.

### Step 4: Update WebReaderView.swift (line ~79)

Currently passes `"text"`, `"prefix"`, `"suffix"` to JS. Update to pass the same values but sourced from the new computed properties (should work without changes if computed props are in place).

### Step 5: Update MCPServer if it references annotation fields directly

Check `MCPServer.swift` and `MindleMCP/main.swift` — if they serialize annotations or reference `.text`/`.prefix`/`.suffix`, they should use the computed properties.

### Step 6: Test round-trip

1. Open the existing `demo-aurora.md.collab.json` (v2 format) — verify it loads and displays correctly
2. Make an annotation, save — verify it writes v3 format
3. Reopen — verify v3 loads correctly
4. Verify the MCP server still works for agent collaboration

### Step 7: Update this file → DONE + completion notes

---

## What NOT to Do
- ❌ Do NOT change the `.collab.json` file extension or naming convention
- ❌ Do NOT break existing v2 sidecar files — they must still load (dual-version decode)
- ❌ Do NOT touch the JS/HTML rendering layer (reader.html) unless strictly necessary — the computed properties should insulate it
- ❌ Do NOT implement the fuzzy anchoring algorithm changes (diff-match-patch) in this task — that's a separate task
- ❌ Do NOT rename the Mindle-internal `.mindle.json` hidden sidecars (those are the internal format, separate from `.collab.json` interchange)

## What Didn't Work
- N/A — this is a fresh task. The v3 schema design is complete and reviewed.

---

## Workflow
```
Quick Desktop (QD)                    Kiro
───────────────────                   ────
1. Designed v3 schema                 (waiting)
2. Created this handoff               (waiting)
                                      3. Implement Swift changes
                                      4. Test round-trip
                                      5. Update status → DONE
6. Verify + archive
```

## Reference Files
- Schema: `/Users/apnaik/Projects/markcollab-standalone/schema/collab.v3.schema.json`
- Migration guide: `/Users/apnaik/Projects/markcollab-standalone/docs/migration-v2-to-v3.md`
- Demo v2 sidecar: `/Users/apnaik/Projects/markcollab/demo-aurora.md.collab.json`
- Mindle DocumentStore: `/Users/apnaik/Projects/markcollab/Sources/mindle/DocumentStore.swift`
- Mindle WebReaderView: `/Users/apnaik/Projects/markcollab/Sources/mindle/WebReaderView.swift`
- Mindle MCPServer: `/Users/apnaik/Projects/markcollab/Sources/mindle/MCPServer.swift`
