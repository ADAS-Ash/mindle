// CollabEngine.swift — CRUD engine for the unified .collab.json sidecar.

import Foundation
import CryptoKit

public final class CollabEngine {
    public var document: CollabDocument = CollabDocument()
    private var sidecarURL: URL?

    public init() {}

    /// Sidecar path: `<file>.md.collab.json`
    public static func sidecarURL(for markdownURL: URL) -> URL {
        markdownURL.appendingPathExtension("collab.json")
    }

    /// Loads existing sidecar or initializes fresh. Updates fileHash.
    public func load(for markdownURL: URL) throws {
        let url = Self.sidecarURL(for: markdownURL)
        sidecarURL = url

        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            document = try decoder.decode(CollabDocument.self, from: data)
        } else {
            document = CollabDocument()
        }

        let mdData = try Data(contentsOf: markdownURL)
        document.fileHash = "sha256:" + SHA256.hash(data: mdData)
            .map { String(format: "%02x", $0) }.joined()
    }

    /// Persists to disk atomically.
    public func save() throws {
        guard let url = sidecarURL else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(document)
        try data.write(to: url, options: .atomic)
    }

    // MARK: - Annotations

    /// Creates a new annotation with the first message as the body.
    @discardableResult
    public func addAnnotation(anchor: TextAnchor, author: String, text: String) -> CollabAnnotation {
        let msg = ThreadMessage(id: UUID().uuidString, author: author, text: text)
        let annotation = CollabAnnotation(
            id: UUID().uuidString, anchor: anchor, author: author, thread: [msg]
        )
        document.annotations.append(annotation)
        return annotation
    }

    /// Appends a reply to an annotation thread.
    public func reply(to annotationID: String, author: String, text: String) {
        guard let idx = document.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        let msg = ThreadMessage(id: UUID().uuidString, author: author, text: text)
        document.annotations[idx].thread.append(msg)
    }

    /// Resolves an annotation.
    public func resolve(annotationID: String, by user: String) {
        guard let idx = document.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        document.annotations[idx].status = .resolved
        document.annotations[idx].resolvedBy = user
        document.annotations[idx].resolvedAt = Date()
    }

    /// Reopens a resolved annotation.
    public func reopen(annotationID: String) {
        guard let idx = document.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        document.annotations[idx].status = .open
        document.annotations[idx].resolvedBy = nil
        document.annotations[idx].resolvedAt = nil
    }

    /// Assigns an annotation to a collaborator.
    public func assign(annotationID: String, to assignee: String) {
        guard let idx = document.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        document.annotations[idx].assignee = assignee
    }

    /// Adds a label to an annotation.
    public func addLabel(annotationID: String, label: String) {
        guard let idx = document.annotations.firstIndex(where: { $0.id == annotationID }) else { return }
        if !document.annotations[idx].labels.contains(label) {
            document.annotations[idx].labels.append(label)
        }
    }

    // MARK: - Collaborators

    /// Registers a collaborator (idempotent — won't overwrite existing).
    public func registerCollaborator(alias: String, collaborator: Collaborator) {
        if document.collaborators[alias] == nil {
            document.collaborators[alias] = collaborator
        }
    }
}
