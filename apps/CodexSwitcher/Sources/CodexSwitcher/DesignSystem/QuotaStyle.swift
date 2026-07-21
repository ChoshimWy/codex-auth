import SwiftUI

// MARK: - Account Usage State

/// Usage state mapped from the remaining percentage.
/// Threshold: <20% warning, ≤0% exhausted (per Stitch DESIGN.md).
enum AccountUsageState: Equatable, Sendable {
    case normal
    case warning
    case exhausted
    case refreshing
    case unavailable
    case unknown
}

// MARK: - Quota Style

/// Stitch status colors applied to quota and progress indicators.
///
/// Color mapping (from DESIGN.md):
///   • Green (#34C759) — online status / healthy credit levels
///   • Orange (#FF9500) — low credit warnings (<20%)
///   • Red (#FF3B30) — exhausted credits / critical errors
///   • Blue (#0058bc) — primary progress / refreshing
enum QuotaStyle {

    /// Threshold from user settings (default 20%).
    private static var warningThreshold: Double {
        let stored = UserDefaults.standard.double(forKey: "lowCapacityThreshold")
        return stored > 0 ? stored : 20
    }

    /// Determines the usage state from the remaining percentage.
    static func state(remainingPercent: Double?) -> AccountUsageState {
        guard let remainingPercent else { return .unknown }
        if remainingPercent <= 0 { return .exhausted }
        if remainingPercent < warningThreshold { return .warning }
        return .normal
    }

    /// Progress bar indicator color per Stitch status palette.
    static func tint(for state: AccountUsageState) -> Color {
        switch state {
        case .normal:     return StitchColor.statusGreen
        case .warning:    return StitchColor.statusOrange
        case .exhausted:  return StitchColor.statusRed
        case .refreshing: return StitchColor.primaryContainer
        case .unavailable: return StitchColor.statusOrange
        case .unknown:    return StitchColor.outline
        }
    }

    /// Progress bar track — low-transparency (10%) of system blue per Stitch spec.
    static let trackColor = StitchColor.trackBackground

    /// Text color for the percentage value based on usage state.
    static func textTint(for state: AccountUsageState) -> Color {
        switch state {
        case .normal:     return StitchColor.onSurface
        case .warning:    return StitchColor.statusOrange
        case .exhausted:  return StitchColor.statusRed
        case .refreshing: return StitchColor.onSurfaceVariant
        case .unavailable: return StitchColor.statusOrange
        case .unknown:    return StitchColor.outline
        }
    }
}
