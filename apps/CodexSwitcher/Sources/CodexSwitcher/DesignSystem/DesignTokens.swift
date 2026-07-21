import SwiftUI

// MARK: - Stitch Codex Liquid Glass Design System
//
// Source: Stitch MCP — "DESIGN.md Design System" project
// Style: Liquid Glass — refined glassmorphism for macOS Menu Bar
//
// Principles:
//   • High-density background blur for legibility against desktop
//   • Translucent layering to establish hierarchy without solid fills
//   • Luminous edges: 1px borders simulating light on glass edges
//   • Soft depth: wide, low-opacity ambient shadows

// MARK: - Color Palette

/// Stitch named colors extracted from the DESIGN.md Design System project.
///
/// All colors auto-adapt to Light / Dark mode using AppKit dynamic `NSColor`.
/// Light values: Stitch DESIGN.md originals (Liquid Glass light palette).
/// Dark values: derived Liquid Glass dark palette — deeper surfaces, lighter text,
/// same status colors (they already work in both modes).
enum StitchColor {

    // MARK: Surface System

    /// Primary background — light: near-white cool; dark: deep macOS panel
    static var surface:         Color { adaptive(light: "#f9f9ff", dark: "#1c1c1e") }
    static var surfaceDim:      Color { adaptive(light: "#d8d9e5", dark: "#2c2c2e") }
    static var surfaceBright:   Color { adaptive(light: "#f9f9ff", dark: "#3a3a3c") }

    static var surfaceContainerLowest:  Color { adaptive(light: "#ffffff", dark: "#1c1c1e") }
    static var surfaceContainerLow:     Color { adaptive(light: "#f1f3fe", dark: "#242426") }
    static var surfaceContainer:        Color { adaptive(light: "#ecedf9", dark: "#2c2c2e") }
    static var surfaceContainerHigh:    Color { adaptive(light: "#e6e8f3", dark: "#38383a") }
    static var surfaceContainerHighest: Color { adaptive(light: "#e0e2ed", dark: "#444446") }

    static var onSurface:        Color { adaptive(light: "#181c23", dark: "#e5e2e3") }
    static var onSurfaceVariant: Color { adaptive(light: "#414755", dark: "#8e8e93") }

    static var inverseSurface:    Color { adaptive(light: "#2d3039", dark: "#e5e2e3") }
    static var inverseOnSurface:  Color { adaptive(light: "#eef0fc", dark: "#313032") }

    static var outline:        Color { adaptive(light: "#717786", dark: "#545458") }
    static var outlineVariant: Color { adaptive(light: "#c1c6d7", dark: "#3a3a3c") }

    static var surfaceTint:    Color { adaptive(light: "#005bc1", dark: "#adc6ff") }
    static var background:     Color { adaptive(light: "#f9f9ff", dark: "#1c1c1e") }
    static var onBackground:   Color { adaptive(light: "#181c23", dark: "#e5e2e3") }
    static var surfaceVariant: Color { adaptive(light: "#e0e2ed", dark: "#2c2c2e") }

    // MARK: Primary (System Blue)

    static var primary:                 Color { adaptive(light: "#0058bc", dark: "#adc6ff") }
    static var onPrimary:              Color { adaptive(light: "#ffffff", dark: "#001a41") }
    static var primaryContainer:        Color { adaptive(light: "#0070eb", dark: "#5ba0f0") }
    static var onPrimaryContainer:      Color { adaptive(light: "#fefcff", dark: "#0d1b33") }
    static var primaryFixed:            Color { adaptive(light: "#d8e2ff", dark: "#1e3255") }
    static var primaryFixedDim:         Color { adaptive(light: "#adc6ff", dark: "#003066") }
    static var onPrimaryFixed:          Color { adaptive(light: "#001a41", dark: "#d8e2ff") }
    static var onPrimaryFixedVariant:   Color { adaptive(light: "#004493", dark: "#adc6ff") }
    static var inversePrimary:          Color { adaptive(light: "#adc6ff", dark: "#0058bc") }

    // MARK: Secondary

    static var secondary:               Color { adaptive(light: "#5d5e63", dark: "#c6c6cb") }
    static var onSecondary:            Color { adaptive(light: "#ffffff", dark: "#1a1b1f") }
    static var secondaryContainer:      Color { adaptive(light: "#e0dfe4", dark: "#46464b") }
    static var onSecondaryContainer:    Color { adaptive(light: "#626267", dark: "#e3e2e7") }
    static var secondaryFixed:          Color { adaptive(light: "#e3e2e7", dark: "#46464b") }
    static var secondaryFixedDim:       Color { adaptive(light: "#c6c6cb", dark: "#2c2c30") }
    static var onSecondaryFixed:        Color { adaptive(light: "#1a1b1f", dark: "#e3e2e7") }
    static var onSecondaryFixedVariant: Color { adaptive(light: "#46464b", dark: "#c6c6cb") }

    // MARK: Tertiary

    static var tertiary:                Color { adaptive(light: "#9e3d00", dark: "#ffb595") }
    static var onTertiary:             Color { adaptive(light: "#ffffff", dark: "#351000") }
    static var tertiaryContainer:       Color { adaptive(light: "#c64f00", dark: "#7c2e00") }
    static var onTertiaryContainer:     Color { adaptive(light: "#fffbff", dark: "#ffdbcc") }
    static var tertiaryFixed:           Color { adaptive(light: "#ffdbcc", dark: "#7c2e00") }
    static var tertiaryFixedDim:        Color { adaptive(light: "#ffb595", dark: "#4a1c00") }
    static var onTertiaryFixed:         Color { adaptive(light: "#351000", dark: "#ffdbcc") }
    static var onTertiaryFixedVariant:  Color { adaptive(light: "#7c2e00", dark: "#ffb595") }

    // MARK: Error

    static var error:            Color { adaptive(light: "#ba1a1a", dark: "#ffb4ab") }
    static var onError:         Color { adaptive(light: "#ffffff", dark: "#690005") }
    static var errorContainer:   Color { adaptive(light: "#ffdad6", dark: "#93000a") }
    static var onErrorContainer: Color { adaptive(light: "#93000a", dark: "#ffdad6") }

    // MARK: Status

    /// Healthy credit levels / online status — works in both modes
    static let statusGreen  = Color(hex: "#34C759")
    /// Low credit warnings (<20%) — works in both modes
    static let statusOrange = Color(hex: "#FF9500")
    /// Exhausted credits / critical errors — works in both modes
    static let statusRed    = Color(hex: "#FF3B30")
    /// Alternative account identification — works in both modes
    static let statusPurple = Color(hex: "#AF52DE")

    // MARK: Avatar Palette

    /// Distinct colors for per-account avatar backgrounds.
    /// Deterministic: same account always gets the same color.
    private static let avatarColors: [(light: String, dark: String)] = [
        ("#0070eb", "#5ba0f0"),  // blue
        ("#af52de", "#c77dff"),  // purple
        ("#ff9500", "#ffa940"),  // orange
        ("#34c759", "#4cd964"),  // green
        ("#ff3b30", "#ff6259"),  // red
        ("#007aff", "#5ba0f0"),  // sapphire
        ("#ff6b35", "#ff8555"),  // vermilion
        ("#0891b2", "#22c5e0"),  // teal
        ("#e84393", "#f065a3"),  // pink
        ("#8b5cf6", "#a78bfa"),  // violet
    ]

    /// Picks a stable avatar color for the given account identifier.
    static func avatarColor(for accountId: String) -> Color {
        let hash = accountId.utf8.reduce(0) { $0 &* 31 &+ Int($1) }
        let (light, dark) = avatarColors[abs(hash) % avatarColors.count]
        return adaptive(light: light, dark: dark)
    }

    // MARK: Glass Effects

    /// Luminous edge — 1px border that simulates light catching glass.
    /// Dark mode: slightly lower opacity to avoid glare.
    static var glassBorder: Color {
        adaptiveColor { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark
                ? NSColor(white: 1, alpha: 0.12)
                : NSColor(white: 1, alpha: 0.2)
        }
    }

    /// Progress bar track — low-transparency blue.
    /// Dark mode: slightly higher opacity for visibility.
    static var trackBackground: Color {
        adaptiveColor { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? "#007aff" : "#007aff"
            let alpha: CGFloat = isDark ? 0.18 : 0.10
            let nsColor = NSColor(hex: hex)
            return nsColor.withAlphaComponent(alpha)
        }
    }

    // MARK: - Adaptive Helpers

    /// Creates a Color that automatically adapts between light and dark hex values.
    private static func adaptive(light: String, dark: String) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }

    /// Creates a Color backed by an adaptive NSColor closure.
    private static func adaptiveColor(_ provider: @escaping (NSAppearance) -> NSColor) -> Color {
        Color(nsColor: NSColor(name: nil, dynamicProvider: provider))
    }
}

// MARK: - Hex Color Initializer

private extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }
}

private extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: CGFloat
        switch hex.count {
        case 6:
            r = CGFloat((int >> 16) & 0xFF) / 255
            g = CGFloat((int >> 8)  & 0xFF) / 255
            b = CGFloat(int         & 0xFF) / 255
        default:
            r = 0; g = 0; b = 0
        }

        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

// MARK: - Spacing

/// Stitch 16pt rhythm — base unit: 4pt
enum AppSpacing {
    static let xxs: CGFloat = 4
    static let xs: CGFloat  = 8    // section-gap
    static let sm: CGFloat  = 12
    static let md: CGFloat  = 16   // outer-padding / inner-padding / main-vertical-gap
    static let lg: CGFloat  = 20
    static let xl: CGFloat  = 24
}

// MARK: - Radius

enum AppRadius {
    /// Badges — pill-like (7pt)
    static let badge: CGFloat = 7
    /// Small elements
    static let small: CGFloat = 8
    /// Cards, buttons, input fields
    static let medium: CGFloat = 12
    /// Account Cards (16pt)
    static let large: CGFloat = 16
    /// Main Popover (22pt — soft, friendly silhouette)
    static let popover: CGFloat = 22
    /// Capsule buttons, pill shapes
    static let full: CGFloat = 9999
}

// MARK: - Sizing

enum AppSize {
    /// Popover — Stitch spec: 380pt fixed width
    static let popoverWidth: CGFloat = 380
    static let preferredPopoverHeight: CGFloat = 620
    static let maximumPopoverHeight: CGFloat = 720

    /// Header
    static let titleBarHeight: CGFloat = 44   // header-height

    /// Avatars
    static let currentAccountAvatar: CGFloat = 44
    static let accountAvatar: CGFloat = 36

    /// Account Rows — 68pt height (row-height-standard)
    static let accountRowHeight: CGFloat = 68

    /// Icon Buttons: 28x28pt (32pt hit area)
    static let iconButton: CGFloat = 28
    static let minimumHitArea: CGFloat = 32

    /// Switch button
    static let switchButtonWidth: CGFloat = 54
    static let switchButtonHeight: CGFloat = 28

    /// Progress Bars — 6pt height, fully rounded
    static let progressHeight: CGFloat = 6
}

// MARK: - Typography

/// Stitch typography system: Inter for UI, JetBrains Mono for digits.
/// Matches DESIGN.md spec for hierarchy and weights.
enum AppTypography {
    /// Popover title — 20px, Semibold, 44px lineHeight
    static let title = Font.system(size: 20, weight: .semibold)

    /// Section header — 13px, Semibold, 16px lineHeight
    static let sectionTitle = Font.system(size: 13, weight: .semibold)

    /// Card title / account name in current card — 16px, Semibold, 20px lineHeight
    static let accountName = Font.system(size: 16, weight: .semibold)

    /// Account name in row — 14px, Semibold
    static let rowAccountName = Font.system(size: 14, weight: .semibold)

    /// Body — 13px, Regular
    static let body = Font.system(size: 13, weight: .regular)

    /// Secondary metadata — 12px, Regular, 16px lineHeight (body-sm)
    static let secondary = Font.system(size: 12, weight: .regular)

    /// Caption / timestamps — 11px, Regular, 14px lineHeight
    static let caption = Font.system(size: 11, weight: .regular)

    /// Badge labels — 11px, Medium, 22px lineHeight
    static let badge = Font.system(size: 11, weight: .medium)

    /// Primary percentage value — 38px, Medium, 44px lineHeight
    static let quotaValue = Font.system(size: 38, weight: .medium)

    // MARK: Monospaced Digits

    /// Progress digit — JetBrains Mono, 13px, Medium, tabular figures
    static let progressMono = Font.system(size: 13, weight: .medium, design: .monospaced)
}
