// CollabMCPExtensions.swift — MCP tool definitions for the unified collab model.
// These extend Mindle v2's base MCP tools with collaboration-aware operations.
// Stubs until wired into the mindle-mcp binary's Unix socket protocol.

import Foundation

enum CollabMCPTool: String, CaseIterable {
    // Inherited from Mindle v2
    case listOpenFiles = "list_open_files"
    case readFile = "read_file"
    case getAnnotations = "get_annotations"
    case clearAnnotation = "clear_annotation"
    case waitForEvent = "wait_for_annotation_event"

    // Collab extensions
    case getCollabAnnotations = "get_collab_annotations"
    case addAnnotation = "add_annotation"
    case replyToAnnotation = "reply_to_annotation"
    case resolveAnnotation = "resolve_annotation"
    case assignAnnotation = "assign_annotation"
    case getCollaborators = "get_collaborators"

    var description: String {
        switch self {
        case .listOpenFiles: return "List files currently open"
        case .readFile: return "Read file content"
        case .getAnnotations: return "Get Mindle annotations (v2 native)"
        case .clearAnnotation: return "Remove an annotation"
        case .waitForEvent: return "Long-poll for annotation events"
        case .getCollabAnnotations: return "Get collab annotations with status/assignee/labels"
        case .addAnnotation: return "Add an annotation (human or agent)"
        case .replyToAnnotation: return "Reply to an annotation thread"
        case .resolveAnnotation: return "Resolve an annotation"
        case .assignAnnotation: return "Assign an annotation to a collaborator"
        case .getCollaborators: return "List collaborators for a document"
        }
    }
}

/// Handles collab MCP tool calls against the unified engine.
struct CollabMCPHandler {
    let engine: CollabEngine
    let identity: IdentityManager

    func handle(tool: CollabMCPTool, input: [String: Any]) -> [String: Any] {
        switch tool {
        case .getCollabAnnotations:
            return ["count": engine.document.annotations.count]

        case .addAnnotation:
            guard let anchorText = input["anchor_text"] as? String,
                  let text = input["text"] as? String else {
                return ["error": "missing anchor_text or text"]
            }
            let author = (input["author"] as? String) ?? identity.alias
            let anchor = TextAnchor(text: anchorText, prefix: "", suffix: "")
            let ann = engine.addAnnotation(anchor: anchor, author: author, text: text)
            return ["id": ann.id, "status": "created"]

        case .replyToAnnotation:
            guard let id = input["annotation_id"] as? String,
                  let text = input["text"] as? String else {
                return ["error": "missing annotation_id or text"]
            }
            let author = (input["author"] as? String) ?? identity.alias
            engine.reply(to: id, author: author, text: text)
            return ["status": "replied"]

        case .resolveAnnotation:
            guard let id = input["annotation_id"] as? String else {
                return ["error": "missing annotation_id"]
            }
            engine.resolve(annotationID: id, by: identity.alias)
            return ["status": "resolved"]

        case .assignAnnotation:
            guard let id = input["annotation_id"] as? String,
                  let assignee = input["assignee"] as? String else {
                return ["error": "missing annotation_id or assignee"]
            }
            engine.assign(annotationID: id, to: assignee)
            return ["status": "assigned"]

        case .getCollaborators:
            return ["collaborators": Array(engine.document.collaborators.keys)]

        case .listOpenFiles, .readFile, .getAnnotations, .clearAnnotation, .waitForEvent:
            return ["error": "delegated to base mindle-mcp"]
        }
    }
}
