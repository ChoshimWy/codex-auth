import SwiftUI

// MARK: - Popover Header

/// Stitch DESIGN.md header spec:
///   • 44pt height (header-height)
///   • Icon buttons: 28x28pt (32pt hit area), transparent bg
///   • Title: 20px Semibold
struct PopoverHeaderView: View {
    let isRefreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(L10n.appTitle)
                .font(AppTypography.title)
                .foregroundStyle(StitchColor.onSurface)

            Spacer()

            Button(action: onRefresh) {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                }
            }
            .buttonStyle(.plain)
            .frame(
                width: AppSize.minimumHitArea,
                height: AppSize.minimumHitArea
            )
            .accessibilityLabel(L10n.appRefreshAX)

            SettingsLink {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(StitchColor.onSurfaceVariant)
            }
            .buttonStyle(.plain)
            .frame(
                width: AppSize.minimumHitArea,
                height: AppSize.minimumHitArea
            )
            .accessibilityLabel(L10n.appSettingsAX)
        }
        .frame(height: AppSize.titleBarHeight)
    }
}
