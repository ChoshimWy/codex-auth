import SwiftUI

// MARK: - Current Account Card

/// Level 2 Glass card per Stitch DESIGN.md spec:
///   • 16pt inner padding, 16pt radius
///   • Slightly opaque glass with luminous edge
///   • Avatar with status dot, badges, dual progress bars
///   • Monospaced digits for quota values (tabular figures)
struct CurrentAccountCard: View {
    let account: CodexAccount

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.sm) {
                avatar

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.xs) {
                        // Online status dot — Stitch green for active
                        Circle()
                            .fill(StitchColor.statusGreen)
                            .frame(width: 8, height: 8)

                        Text(account.alias)
                            .font(AppTypography.accountName)
                            .foregroundStyle(StitchColor.onSurface)
                    }

                    Text(account.email)
                        .font(AppTypography.secondary)
                        .foregroundStyle(StitchColor.onSurfaceVariant)

                    HStack(spacing: AppSpacing.xs) {
                        planBadge
                        sourceBadge
                    }
                }

                Spacer()

                if let usage = account.primaryUsage {
                    Text("\(Int(usage.remainingPercent))%")
                        .font(AppTypography.quotaValue.monospacedDigit())
                        .foregroundStyle(StitchColor.onSurface)
                }
            }

            Divider()
                .overlay(StitchColor.outlineVariant)

            if let usage = account.primaryUsage {
                UsageProgressRow(usage: usage)
            }

            if let usage = account.secondaryUsage {
                Divider()
                    .overlay(StitchColor.outlineVariant)
                UsageProgressRow(usage: usage)
            }

            HStack {
                if let credits = account.credits {
                    Text(L10n.cardResets(credits))
                        .font(AppTypography.body)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                }

                Spacer()

                if let date = account.lastUpdatedAt {
                    Text(L10n.cardUpdated(date.formatted(date: .omitted, time: .shortened)))
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                }
            }
        }
        .padding(AppSpacing.md)
        .elevatedGlassCard(cornerRadius: AppRadius.large)
    }

    // MARK: - Subviews

    /// Avatar with primary color gradient background
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(StitchColor.avatarColor(for: account.id).gradient)

            Text(String(account.alias.prefix(1)))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(
            width: AppSize.currentAccountAvatar,
            height: AppSize.currentAccountAvatar
        )
        .accessibilityHidden(true)
    }

    /// Plan badge — Stitch: light blue background for Plus, subtle pill shape
    private var planBadge: some View {
        Text(L10n.planName(account.plan.rawValue))
            .font(AppTypography.badge)
            .foregroundStyle(planBadgeForeground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(planBadgeBackground)
            .clipShape(Capsule())
    }

    private var planBadgeForeground: Color {
        switch account.plan {
        case .plus, .pro:
            return StitchColor.primaryContainer
        default:
            return StitchColor.onSurfaceVariant
        }
    }

    private var planBadgeBackground: Color {
        switch account.plan {
        case .plus, .pro:
            return StitchColor.primaryFixed
        default:
            return StitchColor.surfaceContainerHigh
        }
    }

    /// API source badge — Stitch: light green for live API
    private var sourceBadge: some View {
        Text(refreshSourceTitle)
            .font(AppTypography.badge)
            .foregroundStyle(sourceBadgeForeground)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(sourceBadgeBackground)
            .clipShape(Capsule())
    }

    private var sourceBadgeForeground: Color {
        switch account.refreshSource {
        case .api:
            return StitchColor.statusGreen
        default:
            return StitchColor.onSurfaceVariant
        }
    }

    private var sourceBadgeBackground: Color {
        switch account.refreshSource {
        case .api:
            return StitchColor.statusGreen.opacity(0.15)
        default:
            return StitchColor.surfaceContainerHigh
        }
    }

    private var refreshSourceTitle: String {
        switch account.refreshSource {
        case .api:   return L10n.sourceAPI
        case .local: return L10n.sourceLocal
        case .cache: return L10n.sourceCached
        case .none:  return L10n.sourceOffline
        }
    }
}
