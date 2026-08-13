import SwiftUI

// MARK: - Menu Bar Popover

struct MenuBarPopoverView: View {
    let store: MenuBarStore

    @Environment(\.colorScheme) private var colorScheme

    /// 弹窗级提示路由:SwiftUI 同一视图链上的多个 `.alert` 只有最后一个生效,
    /// 因此切换确认与隐私披露合并为单一 alert,按优先级路由(隐私优先)。
    private enum PopoverAlert {
        case switchConfirmation
        case privacyDisclosure
        case cliInstallWizard
    }

    private var activeAlert: PopoverAlert? {
        if store.privacyDisclosurePending { return .privacyDisclosure }
        if store.pendingSwitchAccount != nil { return .switchConfirmation }
        if store.showCLIInstallWizard { return .cliInstallWizard }
        return nil
    }

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
                onRefresh: { Task { await store.refresh(userInitiated: true) } },
                onLocalRefresh: { Task { await store.refresh(skipAPI: true, userInitiated: true) } },
                onImport: { store.presentImportSheet() },
                onExport: { store.presentExportSheet() },
                onLogin: { store.presentLoginSheet() },
                onLaunchApp: { Task { await store.launchCodexApp() } },
                onSwitchPrevious: { Task { await store.switchToPrevious() } }
            )

            if store.accounts.isEmpty && !store.isRefreshing {
                emptyState
            }

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
                                isRemoving: store.removingAccountID == account.id,
                                switchDisabled: store.mutationsLocked || !store.supportsSwitchCommand,
                                aliasDisabled: store.mutationsLocked || !store.supportsAliasCommand,
                                removeDisabled: store.mutationsLocked || !store.supportsRemoveCommand,
                                onSwitch: { store.requestSwitch(to: account) },
                                onCopyEmail: { store.copyEmail(account) },
                                onEditAlias: { store.presentAliasSheet(for: account) },
                                onRemove: { store.requestRemove(account) }
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
                .confirmationDialog(
                    L10n.removeConfirmTitle(store.pendingRemoveAccount?.alias ?? ""),
                    isPresented: Binding(
                        get: { store.pendingRemoveAccount != nil },
                        set: { if !$0 { store.cancelRemove() } }
                    ),
                    titleVisibility: .visible
                ) {
                    Button(L10n.removeConfirmButton, role: .destructive) {
                        store.confirmRemove()
                    }
                } message: {
                    Text(L10n.removeConfirmMessage(store.pendingRemoveAccount?.email ?? ""))
                }
            }

            if let notice = store.noticeMessage {
                Text(notice)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
                    .fixedSize(horizontal: false, vertical: true)
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
                Button(L10n.quit) { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                Text("·")
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
        .sheet(isPresented: Binding(
            get: { store.aliasSheetAccount != nil },
            set: { if !$0 { store.dismissAliasSheet() } }
        )) {
            AliasEditorSheet(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.showImportSheet },
            set: { store.showImportSheet = $0 }
        )) {
            ImportAccountSheet(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.showExportSheet },
            set: { store.showExportSheet = $0 }
        )) {
            ExportAccountSheet(store: store)
        }
        .sheet(isPresented: Binding(
            get: { store.showLoginSheet },
            set: { if !$0 { store.dismissLoginSheet() } }
        )) {
            LoginSheet(store: store)
        }
        .alert(alertTitle, isPresented: Binding(
            get: { activeAlert != nil },
            set: { if !$0 { dismissActiveAlert() } }
        )) {
            switch activeAlert {
            case .switchConfirmation:
                Button("Cancel", role: .cancel) { store.cancelSwitch() }
                Button("Switch") { store.confirmSwitch() }
            case .privacyDisclosure:
                Button(L10n.privacyCancel, role: .cancel) { store.declinePrivacyDisclosure() }
                Button(L10n.privacyLocalOnly) { Task { await store.refresh(skipAPI: true, userInitiated: true) } }
                Button(L10n.privacyContinue) {
                    store.acceptPrivacyDisclosure()
                    Task { await store.refresh(userInitiated: true) }
                }
            case .cliInstallWizard:
                Button(L10n.cliInstallWizardSkip, role: .cancel) { store.skipCLIInstallWizard() }
                Button(L10n.cliInstallWizardInstall) { store.acceptCLIInstallWizard() }
            case nil:
                EmptyView()
            }
        } message: {
            switch activeAlert {
            case .switchConfirmation:
                Text("Switching accounts will update the active Codex session.")
            case .privacyDisclosure:
                Text(L10n.privacyMessage)
            case .cliInstallWizard:
                Text(store.cliInstallWizardMessageText)
            case nil:
                EmptyView()
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.emptyTitle)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(StitchColor.onSurface)
            Text(L10n.emptyMessage)
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.onSurfaceVariant)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button(L10n.emptyImportAction) { store.presentImportSheet() }
                Button(L10n.emptyLoginAction) { store.presentLoginSheet() }
                Spacer()
            }
        }
        .padding(.vertical, AppSpacing.xxs)
    }

    private var alertTitle: String {
        switch activeAlert {
        case .switchConfirmation:
            return "Switch to \(store.pendingSwitchAccount?.alias ?? "")?"
        case .privacyDisclosure:
            return L10n.privacyTitle
        case .cliInstallWizard:
            return L10n.cliInstallWizardTitle
        case nil:
            return ""
        }
    }

    private func dismissActiveAlert() {
        switch activeAlert {
        case .switchConfirmation:
            store.cancelSwitch()
        case .privacyDisclosure:
            store.declinePrivacyDisclosure()
        case .cliInstallWizard:
            store.skipCLIInstallWizard()
        case nil:
            break
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
