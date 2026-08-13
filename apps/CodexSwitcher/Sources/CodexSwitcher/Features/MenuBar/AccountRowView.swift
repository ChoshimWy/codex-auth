import SwiftUI

// MARK: - Account Row View

/// Compact row: avatar · name / email · usage% · ⋯ menu
///
/// Switch action lives inside the ⋯ menu (no standalone button).
/// Hover uses Stitch light-injection — white overlay at 10-15%,
/// adaptive to light / dark mode.
struct AccountRowView: View {
    let account: CodexAccount
    let isSwitching: Bool
    let isRemoving: Bool
    /// `state_uncertain` 锁定或能力探测不支持时禁用对应变更项(FR-13)。
    let switchDisabled: Bool
    let aliasDisabled: Bool
    let removeDisabled: Bool
    let onSwitch: () -> Void
    let onCopyEmail: () -> Void
    let onEditAlias: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            avatar

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(account.alias)
                    .font(AppTypography.rowAccountName)
                    .foregroundStyle(StitchColor.onSurface)
                    .lineLimit(1)

                Text(account.email)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .layoutPriority(1)

            Spacer(minLength: AppSpacing.xxs)

            usageBadge

            moreMenu
        }
        .padding(.horizontal, AppSpacing.sm)
        .frame(height: AppSize.accountRowHeight)
    }

    // MARK: - Avatar

    private var avatar: some View {
        let color = StitchColor.avatarColor(for: account.id)

        return ZStack {
            Circle()
                .fill(color.gradient)

            Text(String(account.alias.prefix(1)))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: AppSize.accountAvatar, height: AppSize.accountAvatar)
        .accessibilityHidden(true)
    }

    // MARK: - Usage Badge

    @ViewBuilder
    private var usageBadge: some View {
        if let usage = account.primaryUsage {
            let pct = Int(usage.remainingPercent)
            let state = QuotaStyle.state(remainingPercent: usage.remainingPercent)

            Text("\(pct)%")
                .font(AppTypography.progressMono)
                .foregroundStyle(QuotaStyle.textTint(for: state))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background {
                    Capsule()
                        .fill(QuotaStyle.tint(for: state).opacity(0.12))
                }
                .fixedSize()
        } else {
            Text("—")
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.outline)
                .fixedSize()
        }
    }

    // MARK: - More Menu

    /// ⋯ menu — contains Switch, Copy, Remove actions.
    private var moreMenu: some View {
        Menu {
            if isSwitching {
                Text(L10n.rowSwitching)
            } else if isRemoving {
                Text(L10n.rowRemoving)
            } else {
                Button(L10n.rowSwitch, action: onSwitch)
                    .disabled(switchDisabled)
            }
            Divider()
            Button(L10n.rowEditAlias, action: onEditAlias)
                .disabled(aliasDisabled)
            Divider()
            Button(L10n.rowCopyEmail, action: onCopyEmail)
            Divider()
            Button(L10n.rowRemove, role: .destructive, action: onRemove)
                .disabled(removeDisabled)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(StitchColor.onSurfaceVariant)
                .frame(width: AppSize.iconButton, height: AppSize.iconButton)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("\(account.alias) more options")
    }
}
