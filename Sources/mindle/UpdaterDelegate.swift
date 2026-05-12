import Foundation
import Sparkle

/// UserDefaults key for the "Include Pre-release Updates" opt-in. Mirrored
/// by the `@AppStorage` toggle in the App menu and consulted on every
/// Sparkle update check via `allowedChannels(for:)`.
let kBetaUpdatesKey = "MindleBetaUpdates"

/// Bridges the user's beta opt-in into Sparkle. Two responsibilities:
///
///   1. `allowedChannels(for:)` — when the user has opted in, return the
///      `beta` channel so the updater accepts appcast items tagged
///      `<sparkle:channel>beta</sparkle:channel>`. Stable items (no
///      channel tag) are always visible regardless.
///
///   2. `versionComparator(for:)` — Sparkle's default comparator treats
///      `2.1.0-rc1` as *newer* than `2.1.0` (extra suffix wins by string
///      length). Semver says the opposite. We provide a semver-aware
///      comparator so a beta user on `2.1.0-rc1` correctly upgrades to
///      the `2.1.0` stable release when it ships.
final class UpdaterDelegate: NSObject, SPUUpdaterDelegate {
    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        if UserDefaults.standard.bool(forKey: kBetaUpdatesKey) {
            return ["beta"]
        }
        return []
    }

    func versionComparator(for updater: SPUUpdater) -> SUVersionComparison? {
        SemverComparator.shared
    }
}

/// Semver-ish version comparator: splits on the first `-` to separate
/// the dotted-number version from a pre-release tag. Stable (no tag)
/// outranks any pre-release at the same version; tag-vs-tag falls back
/// to ASCII compare, which orders `rc1 < rc2` correctly.
@objc final class SemverComparator: NSObject, SUVersionComparison {
    static let shared = SemverComparator()

    func compareVersion(_ versionA: String, toVersion versionB: String) -> ComparisonResult {
        let (aMain, aPre) = split(versionA)
        let (bMain, bPre) = split(versionB)
        let mainCmp = compareDotted(aMain, bMain)
        if mainCmp != .orderedSame { return mainCmp }
        switch (aPre, bPre) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending  // stable > pre-release
        case (_, nil): return .orderedAscending   // pre-release < stable
        case let (a?, b?): return a.compare(b)
        }
    }

    private func split(_ v: String) -> (String, String?) {
        if let dash = v.firstIndex(of: "-") {
            return (String(v[..<dash]), String(v[v.index(after: dash)...]))
        }
        return (v, nil)
    }

    private func compareDotted(_ a: String, _ b: String) -> ComparisonResult {
        let ap = a.split(separator: ".").map { Int($0) ?? 0 }
        let bp = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(ap.count, bp.count)
        for i in 0..<n {
            let av = i < ap.count ? ap[i] : 0
            let bv = i < bp.count ? bp[i] : 0
            if av < bv { return .orderedAscending }
            if av > bv { return .orderedDescending }
        }
        return .orderedSame
    }
}
