// IdentityManager.swift — Local user identity for collaboration.
// Stores alias, display name, and color in UserDefaults. On first launch,
// isFirstLaunch() returns true so the app can show a setup sheet.

import Foundation

/// Manages the current user's collaboration identity, persisted locally in UserDefaults.
public final class IdentityManager {
    public static let shared = IdentityManager()

    private let defaults = UserDefaults.standard
    private enum Keys {
        static let alias = "markcollab.alias"
        static let displayName = "markcollab.displayName"
        static let color = "markcollab.color"
    }

    /// Preset color palette for the identity setup picker.
    public static let defaultColors: [String] = [
        "#4A90D9", "#E57373", "#81C784", "#FFB74D",
        "#BA68C8", "#4DD0E1", "#F06292", "#AED581"
    ]

    /// True if the user hasn't set up their identity yet (no alias in UserDefaults).
    public func isFirstLaunch() -> Bool {
        defaults.string(forKey: Keys.alias) == nil
    }

    /// Returns the current user as a Collaborator struct.
    public func whoAmI() -> Collaborator {
        Collaborator(
            displayName: defaults.string(forKey: Keys.displayName) ?? "Anonymous",
            color: defaults.string(forKey: Keys.color) ?? Self.defaultColors[0],
            email: nil
        )
    }

    /// The user's short alias (used as author in comments/changes).
    public var alias: String {
        defaults.string(forKey: Keys.alias) ?? "anonymous"
    }

    /// Persists the user's chosen identity.
    public func save(alias: String, displayName: String, color: String) {
        defaults.set(alias, forKey: Keys.alias)
        defaults.set(displayName, forKey: Keys.displayName)
        defaults.set(color, forKey: Keys.color)
    }
}
