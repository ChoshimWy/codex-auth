import SwiftUI

// MARK: - Usage Progress Row

/// Stitch progress bar — 6pt height, fully rounded caps, status-color tint.
struct UsageProgressRow: View {
    let usage: UsageWindow

    private var progress: Double {
        usage.remainingPercent / 100
    }

    private var state: AccountUsageState {
        QuotaStyle.state(remainingPercent: usage.remainingPercent)
    }

    var body: some View {
        VStack(spacing: AppSpacing.xs) {
            HStack {
                Text(L10n.cardRemaining)
                    .font(AppTypography.body)
                    .foregroundStyle(StitchColor.onSurface)

                Spacer()

                Text("\(Int(usage.remainingPercent))%")
                    .font(AppTypography.progressMono)
                    .foregroundStyle(QuotaStyle.textTint(for: state))
            }

            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(QuotaStyle.tint(for: state))
                .frame(height: AppSize.progressHeight)
                .clipShape(Capsule())

            if let resetAt = usage.resetAt {
                HStack {
                    Spacer()
                    Text(L10n.usageResets(resetAt.formatted(date: .abbreviated, time: .shortened)))
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(usage.remainingPercent))% remaining")
    }
}
