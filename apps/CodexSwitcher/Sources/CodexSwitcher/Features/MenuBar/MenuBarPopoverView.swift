import SwiftUI

// MARK: - Menu Bar Popover

struct MenuBarPopoverView: View {
    let store: MenuBarStore

    @Environment(\.colorScheme) private var colorScheme

    /// Maximum visible Other Accounts rows before scrolling.
    private let maxVisibleRows = 5

    /// Height of the row list area, capped at `maxVisibleRows`.
    private var listHeight: CGFloat {
        let rowCount = min(store.inactiveAccounts.count, maxVisibleRows)
        let contentH = CGFloat(rowCount) * AppSize.accountRowHeight
        let paddingH = AppSpacing.xxs * 2    // vertical padding inside card
        let shadowH: CGFloat = 26             // glass card shadow breathing room
        return max(contentH + paddingH + shadowH, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            PopoverHeaderView(
                isRefreshing: store.isRefreshing,
                onRefresh: { Task { await store.refresh() } }
            )

            if let activeAccount = store.activeAccount {
                CurrentAccountCard(account: activeAccount)
            }

            if !store.inactiveAccounts.isEmpty {
                sectionTitle(L10n.sectionOtherAccounts)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.inactiveAccounts) { account in
                            AccountRowView(
                                account: account,
                                isSwitching: store.switchingAccountID == account.id,
                                onSwitch: { store.requestSwitch(to: account) }
                            )

                            if account.id != store.inactiveAccounts.last?.id {
                                Divider()
                                    .overlay(StitchColor.outlineVariant)
                                    .padding(.leading, 62)
                            }
                        }
                    }
                    .padding(.vertical, AppSpacing.xxs)
                    .liquidGlassCard(cornerRadius: AppRadius.large)
                }
                .scrollClipDisabled()
                .frame(minHeight: min(listHeight, AppSize.accountRowHeight),
                       idealHeight: listHeight,
                       maxHeight: listHeight)
            }

            // Footer
            HStack {
                if let sync = store.lastSyncTime {
                    Text(L10n.footerLastSync(sync.formatted(date: .omitted, time: .shortened)))
                } else if let error = store.errorMessage {
                    Text(error).foregroundStyle(StitchColor.statusOrange)
                } else {
                    Text(L10n.footerLoading)
                }
                Spacer()
                Text(L10n.footerAccounts(store.accounts.count))
            }
            .font(AppTypography.caption)
            .foregroundStyle(StitchColor.onSurfaceVariant)
        }
        .padding(AppSpacing.md)
        .fixedSize(horizontal: false, vertical: true)
        .frame(width: AppSize.popoverWidth, alignment: .topLeading)
        // Liquid Glass popover shell
        .background {
            RoundedRectangle(cornerRadius: AppRadius.popover, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .clipShape(
            RoundedRectangle(cornerRadius: AppRadius.popover, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.popover, style: .continuous)
                .strokeBorder(StitchColor.glassBorder, lineWidth: 0.8)
        }
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12),
            radius: colorScheme == .dark ? 24 : 18,
            y: colorScheme == .dark ? 4 : 8
        )
        .alert("Switch to \(store.pendingSwitchAccount?.alias ?? "")?", isPresented: Binding(
            get: { store.pendingSwitchAccount != nil },
            set: { if !$0 { store.cancelSwitch() } }
        )) {
            Button("Cancel", role: .cancel) { store.cancelSwitch() }
            Button("Switch") { store.confirmSwitch() }
        } message: {
            Text("Switching accounts will update the active Codex session.")
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.sectionTitle)
            .foregroundStyle(StitchColor.onSurfaceVariant)
    }
}

#Preview("Light") {
    MenuBarPopoverView(store: MenuBarStore())
        .preferredColorScheme(.light)
}

#Preview("Dark") {
    MenuBarPopoverView(store: MenuBarStore())
        .preferredColorScheme(.dark)
}
