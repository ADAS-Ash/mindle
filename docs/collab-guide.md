# Collab Guide

How to use MarkCollab's team collaboration features.

## Getting Started

1. Build: `./build.sh`
2. Open a markdown file: `open -a build/Mindle.app file.md`
3. Click the 💬 button in the toolbar to open the comment panel
4. Set your identity by clicking `● anonymous` in the panel header

## Adding Comments

1. Select text in the reader pane
2. Click `+` in the panel header (or press ⌘⇧K)
3. Type your comment in the dialog and click "Add"

The comment appears in the panel and the anchored text is highlighted in the reader.

## Replying & Resolving

- **Reply:** Type in the reply box at the bottom of any comment card and click "Reply"
- **Resolve:** Click "Resolve" to mark a thread as addressed
- **Reopen:** Click "Reopen" on a resolved comment to continue discussion

## Assign & Labels

- **Assign:** Click "Assign ▾" → select a collaborator from the dropdown
- **Labels:** Click "Labels ▾" → pick from: question, blocker, nit, todo, suggestion

## Inline Highlights

When the collab panel is open, commented passages are highlighted in the reader pane with the author's color (as an underline). Click any highlight to jump to that comment in the panel.

New comments appear as highlights immediately after creation.

## Sorting & Filtering

- **Filter:** All / Open / Resolved / My Assignments
- **Sort:** Newest first / Oldest first / Doc position

## Refresh

Click ↻ to reload the sidecar from disk — useful after a collaborator pushes changes via OneDrive or shared drive sync.

## For AI Agents (MCP)

Agents connect via the `mindle-mcp` binary and can use these collab ops:

- `get_collab_annotations` — read the full `.collab.json` for a file
- `collab_reply` — reply to a thread (author defaults to "agent")
- `collab_resolve` — resolve an annotation

## Sidecar Format

Collaboration data lives in `<file>.md.collab.json` alongside the markdown. Removing this file removes all collab metadata without affecting the document.
