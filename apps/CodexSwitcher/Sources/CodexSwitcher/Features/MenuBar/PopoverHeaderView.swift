import SwiftUI

// MARK: - Popover Header

/// Stitch DESIGN.md header spec:
///   • 44pt height (header-height)
///   • Icon buttons: 28x28pt (32pt hit area), transparent bg
///   • Title: 20px Semibold
///
/// Refresh 提供两种模式:API 刷新(默认)与 local-only 刷新(`--skip-api`,
/// 数据可能滞后,见 FR-6)。
struct PopoverHeaderView: View {
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onLocalRefresh: () -> Void
    let onImport: () -> Void
    let onExport: () -> Void
    let onLogin: () -> Void
    let onLaunchApp: () -> Void
    let onSwitchPrevious: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Text(L10n.appTitle)
                .font(AppTypography.title)
                .foregroundStyle(StitchColor.onSurface)

            Spacer()

            if isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(
                        width: AppSize.minimumHitArea,
                        height: AppSize.minimumHitArea
                    )
            } else {
                Menu {
                    Button(L10n.headerRefreshAPI, action: onRefresh)
                    Button(L10n.headerRefreshLocal, action: onLocalRefresh)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                        .frame(
                            width: AppSize.minimumHitArea,
                            height: AppSize.minimumHitArea
                        )
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .accessibilityLabel(L10n.appRefreshAX)
            }

            Menu {
                Button(L10n.headerAddLogin, action: onLogin)
                Button(L10n.headerSwitchPrevious, action: onSwitchPrevious)
                Divider()
                Button(L10n.headerAddImport, action: onImport)
                Button(L10n.headerAddExport, action: onExport)
                Divider()
                Button(L10n.headerLaunchApp, action: onLaunchApp)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(StitchColor.onSurfaceVariant)
                    .frame(
                        width: AppSize.minimumHitArea,
                        height: AppSize.minimumHitArea
                    )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel(L10n.headerAddAX)

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
