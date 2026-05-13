// CollabTypes.swift — Unified sidecar schema (v2.0) for humans AND agents.
// A single .collab.json per markdown file stores all collaboration state:
// collaborator registry, threaded annotations with status/assignee/labels.
// Agents (via MCP) and humans (via UI) are just different collaborator types.

import Foundation

/// Root document stored in `<file>.md.collab.json`.
public struct CollabDocument: Codable {
    public var version: String = "2.0"
    public var fileHash: String = ""
    public var collaborators: [String: Collaborator] = [:]
    public var annotations: [CollabAnnotation] = []
    public init() {}
}

/// A participant — human or agent. Keyed by alias in the collaborators map.
public struct Collaborator: Codable {
    public var displayName: String
    public var color: String
    public var type: CollaboratorType
    public var email: String?
    public var mcp: Bool?  // true if this collaborator connects via MCP
    public init(displayName: String, color: String, type: CollaboratorType = .human, email: String? = nil, mcp: Bool? = nil) {
        self.displayName = displayName; self.color = color; self.type = type
        self.email = email; self.mcp = mcp
    }
}

public enum CollaboratorType: String, Codable {
    case human
    case agent
}

/// An annotation anchored to a text range, with a threaded discussion.
public struct CollabAnnotation: Codable, Identifiable {
    public var id: String
    public var anchor: TextAnchor
    public var author: String          // who created it
    public var status: AnnotationStatus = .open
    public var assignee: String?
    public var labels: [String] = []
    public var thread: [ThreadMessage] = []
    public var createdAt: Date
    public var resolvedBy: String?
    public var resolvedAt: Date?
    public init(id: String, anchor: TextAnchor, author: String, createdAt: Date = Date(),
                status: AnnotationStatus = .open, assignee: String? = nil, labels: [String] = [],
                thread: [ThreadMessage] = [], resolvedBy: String? = nil, resolvedAt: Date? = nil) {
        self.id = id; self.anchor = anchor; self.author = author; self.createdAt = createdAt
        self.status = status; self.assignee = assignee; self.labels = labels
        self.thread = thread; self.resolvedBy = resolvedBy; self.resolvedAt = resolvedAt
    }
}

public enum AnnotationStatus: String, Codable {
    case open, resolved, wontfix
}

/// A single message in an annotation thread — from any collaborator type.
public struct ThreadMessage: Codable, Identifiable {
    public var id: String
    public var author: String
    public var text: String
    public var createdAt: Date
    public init(id: String, author: String, text: String, createdAt: Date = Date()) {
        self.id = id; self.author = author; self.text = text; self.createdAt = createdAt
    }
}

/// Content-addressable text anchor with surrounding context.
public struct TextAnchor: Codable {
    public var text: String
    public var prefix: String
    public var suffix: String
    public var lineNumber: Int?
    public init(text: String, prefix: String, suffix: String, lineNumber: Int? = nil) {
        self.text = text; self.prefix = prefix; self.suffix = suffix; self.lineNumber = lineNumber
    }
}
