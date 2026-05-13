// MergeEngine.swift — Conflict resolution for concurrent sidecar edits.
// Strategy: union merge with last-writer-wins for status conflicts.

import Foundation

public final class MergeEngine {

    public struct MergeResult {
        public var merged: CollabDocument
        public var conflicts: [Conflict]
    }

    public struct Conflict {
        public var description: String
        public var localValue: String
        public var remoteValue: String
    }

    /// Union-merges remote into local. New annotations/messages appended; duplicates by ID skipped.
    public static func merge(local: CollabDocument, remote: CollabDocument) -> MergeResult {
        var merged = local
        var conflicts: [Conflict] = []

        // Merge collaborators (new from remote added)
        for (key, collab) in remote.collaborators where merged.collaborators[key] == nil {
            merged.collaborators[key] = collab
        }

        // Merge annotations by ID
        let localIDs = Set(local.annotations.map(\.id))
        for annotation in remote.annotations where !localIDs.contains(annotation.id) {
            merged.annotations.append(annotation)
        }

        // Merge thread messages into shared annotations
        for (idx, localAnn) in local.annotations.enumerated() {
            if let remoteAnn = remote.annotations.first(where: { $0.id == localAnn.id }) {
                let localMsgIDs = Set(localAnn.thread.map(\.id))
                for msg in remoteAnn.thread where !localMsgIDs.contains(msg.id) {
                    merged.annotations[idx].thread.append(msg)
                }
                // Detect status conflicts
                if remoteAnn.status != localAnn.status {
                    conflicts.append(Conflict(
                        description: "Annotation \(localAnn.id) has conflicting status",
                        localValue: localAnn.status.rawValue,
                        remoteValue: remoteAnn.status.rawValue
                    ))
                }
            }
        }

        return MergeResult(merged: merged, conflicts: conflicts)
    }
}
