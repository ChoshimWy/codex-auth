import SwiftUI

// MARK: - Liquid Glass Card

/// Stitch Liquid Glass card modifier — refined glassmorphism per DESIGN.md spec.
///
/// Elevation levels (per Stitch):
///   1. Popover Base — strong blur, luminous edge, wide-cast shadow
///   2. Cards/Rows — slightly more opaque, "lifted" without heavy shadows
///   3. Hover/Interaction — light-injection (white overlay 10-15%)
///
/// Dark mode: shadows use deeper black with wider diffusion; materials auto-adapt.
struct LiquidGlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(StitchColor.surfaceContainerLow)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                // Luminous edge — 1px border simulating light catching glass
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        StitchColor.glassBorder,
                        lineWidth: contrast == .increased ? 1.2 : 0.8
                    )
            }
            .shadow(
                // Soft depth — dark mode uses deeper, more diffused shadow
                color: shadowColor,
                radius: colorScheme == .dark ? 24 : 18,
                y: colorScheme == .dark ? 4 : 8
            )
    }

    private var shadowColor: Color {
        if reduceTransparency {
            return Color.black.opacity(colorScheme == .dark ? 0.15 : 0.08)
        }
        return Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
    }
}

// MARK: - Glass Elevation Variants

/// Level 2 Glass — for cards and rows nested within the popover.
/// Slightly more opaque background with a tighter shadow.
struct ElevatedGlassCardModifier: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                if reduceTransparency {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(StitchColor.surfaceContainer)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.regularMaterial)
                }
            }
            .clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        StitchColor.glassBorder,
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(
                    reduceTransparency
                        ? (colorScheme == .dark ? 0.08 : 0.04)
                        : (colorScheme == .dark ? 0.16 : 0.06)
                ),
                radius: colorScheme == .dark ? 10 : 8,
                y: colorScheme == .dark ? 2 : 3
            )
    }
}

// MARK: - Light Injection Hover

/// Stitch Level 3 — Light-injection technique for hover states.
/// Uses a white overlay at 10-15% opacity to signify interactivity,
/// rather than shifting the element's position.
/// Works in both light and dark modes (semi-transparent white overlay).
struct LightInjectionHoverModifier: ViewModifier {
    let isHovering: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                if isHovering {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Level 1 — Popover base glass with luminous edge and wide shadow
    func liquidGlassCard(
        cornerRadius: CGFloat = AppRadius.large
    ) -> some View {
        modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius
            )
        )
    }

    /// Level 2 — Elevated card with tighter shadow, for nested content
    func elevatedGlassCard(
        cornerRadius: CGFloat = AppRadius.large
    ) -> some View {
        modifier(
            ElevatedGlassCardModifier(
                cornerRadius: cornerRadius
            )
        )
    }

    /// Level 3 — Light-injection hover highlight
    func lightInjectionHover(
        isHovering: Bool,
        cornerRadius: CGFloat = AppRadius.medium
    ) -> some View {
        modifier(
            LightInjectionHoverModifier(
                isHovering: isHovering,
                cornerRadius: cornerRadius
            )
        )
    }
}
