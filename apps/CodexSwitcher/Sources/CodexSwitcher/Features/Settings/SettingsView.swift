import SwiftUI
import ServiceManagement
import UserNotifications

struct SettingsView: View {
    let store: MenuBarStore

    @AppStorage("lowCapacityThreshold") private var threshold: Double = 20.0
    @AppStorage("confirmBeforeSwitch") private var confirmSwitch: Bool = false
    @AppStorage("refreshInterval") private var refreshInterval: Int = 300
    @AppStorage("language") private var language: String = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

    @Environment(\.dismiss) private var dismiss

    private let intervals: [(Int, String)] = [
        (60, "1 min"), (120, "2 min"), (300, "5 min"),
        (600, "10 min"), (900, "15 min"), (1800, "30 min"),
    ]

    var body: some View {
        TabView {
            GeneralSettingsView(
                store: store,
                threshold: $threshold,
                confirmSwitch: $confirmSwitch,
                refreshInterval: $refreshInterval,
                launchAtLogin: $launchAtLogin,
                intervals: intervals
            )
            .tabItem { Label(L10n.settingsGeneral, systemImage: "gearshape") }
            .frame(width: 440, height: 360)

            AccountsSettingsView(store: store)
                .tabItem { Label(L10n.settingsAccounts, systemImage: "person.2") }
                .frame(width: 460, height: 360)

            LanguageView(language: $language)
                .tabItem { Label(L10n.settingsLanguage, systemImage: "globe") }
                .frame(width: 440, height: 360)

            AboutView()
                .tabItem { Label(L10n.settingsAbout, systemImage: "info.circle") }
                .frame(width: 440, height: 360)
        }
        .padding(20)
    }
}

// MARK: - CLI (PRD Section 13)

/// CLI 安装/更新:内置与已装版本展示、一键安装/覆盖、目标目录选择、PATH 引导。
private struct CLIInstallSettingsSection: View {
    let store: MenuBarStore

    @State private var showDowngradeConfirm = false

    var body: some View {
        Section {
            if let info = store.cliInstallInfo {
                Text(L10n.cliInstallBundledVersion(info.bundledVersion ?? "?"))
                    .font(AppTypography.caption)
                Text(info.installedVersion.map { L10n.cliInstallInstalledVersion($0) }
                    ?? L10n.cliInstallNotInstalled)
                    .font(AppTypography.caption)
                if let path = info.installedPath {
                    Text(L10n.cliInstallInstalledPath(path))
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                }
                if let target = info.targetDirectory {
                    Text(L10n.cliInstallTarget(target))
                        .font(AppTypography.caption)
                        .foregroundStyle(StitchColor.onSurfaceVariant)
                    if target.hasSuffix("/.local/bin") {
                        Text(L10n.cliInstallPathHint)
                            .font(AppTypography.caption)
                            .foregroundStyle(StitchColor.statusOrange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let message = store.cliInstallMessage {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
            }

            Button(L10n.cliInstallAction) {
                if store.cliInstallNeedsDowngradeConfirmation {
                    showDowngradeConfirm = true
                } else {
                    Task { await store.installOrUpdateCLI() }
                }
            }
        } header: {
            Text(L10n.cliInstallTitle)
        } footer: {
            Text(L10n.cliInstallNote)
        }
        .confirmationDialog(
            L10n.cliInstallDowngradeTitle,
            isPresented: $showDowngradeConfirm,
            titleVisibility: .visible
        ) {
            Button(L10n.cliInstallDowngradeConfirm, role: .destructive) {
                Task { await store.installOrUpdateCLI() }
            }
        } message: {
            // 展示两版本(PRD 13.3:新版本覆盖前显式确认)。
            Text(store.cliInstallWizardMessageText)
        }
        .task {
            if store.cliInstallInfo == nil {
                await store.loadCLIInstallInfo()
            }
        }
    }
}

// MARK: - Accounts (FR-9 / FR-10)

/// 账户管理 Tab:导入(standard/cpa/purge)与导出(standard/cpa)。
private struct AccountsSettingsView: View {
    let store: MenuBarStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ImportAccountSheet(store: store, showsCloseButton: false)
                Divider()
                ExportAccountSheet(store: store, showsCloseButton: false)
                Divider()
                MaintenanceSection(store: store)
            }
            .padding(.vertical, AppSpacing.md)
        }
    }
}

// MARK: - Maintenance (clean / live interval)

/// 维护区:清理备份与过期文件、CLI live TUI 刷新间隔(PRD Section 10)。
private struct MaintenanceSection: View {
    let store: MenuBarStore

    @State private var interval: Int = 60

    private let intervals: [(Int, String)] = [
        (60, "1 min"), (120, "2 min"), (300, "5 min"), (600, "10 min"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(L10n.maintenanceTitle)
                .font(AppTypography.sectionTitle)
                .foregroundStyle(StitchColor.onSurface)

            HStack {
                Text(L10n.maintenanceCleanDescription)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
                Spacer()
                Button(L10n.maintenanceCleanAction) {
                    Task { await store.cleanBackups() }
                }
                .disabled(store.managementBusy)
            }

            if let summary = store.lastCleanSummary {
                Text(L10n.maintenanceCleanSummary(
                    summary.authBackupsRemoved ?? 0,
                    summary.registryBackupsRemoved ?? 0,
                    summary.staleSnapshotFilesRemoved ?? 0
                ))
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.statusGreen)
            }

            HStack {
                Text(L10n.maintenanceLiveInterval)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
                Spacer()
                Picker("", selection: $interval) {
                    ForEach(intervals, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                .onChange(of: interval) { _, newValue in
                    Task { await store.setLiveInterval(newValue) }
                }
            }
        }
        .task {
            await store.loadLiveInterval()
            if let current = store.liveIntervalSeconds {
                interval = current
            }
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    let store: MenuBarStore
    @Binding var threshold: Double
    @Binding var confirmSwitch: Bool
    @Binding var refreshInterval: Int
    @Binding var launchAtLogin: Bool
    let intervals: [(Int, String)]

    var body: some View {
        Form {
            Section {
                Slider(value: $threshold, in: 5...50, step: 5) {
                    Text(L10n.settingsLowThreshold(Int(threshold)))
                }
                Toggle(L10n.settingsConfirmSwitch, isOn: $confirmSwitch)
            }

            Section {
                Picker(L10n.settingsRefreshInterval, selection: $refreshInterval) {
                    ForEach(intervals, id: \.0) { val, label in
                        Text(label).tag(val)
                    }
                }
                .pickerStyle(.menu)
            }

            Section {
                Toggle(L10n.settingsLaunchAtLogin, isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                        } catch {
                            launchAtLogin = false
                        }
                    }
            }

            Section {
                Toggle(L10n.settingsNotifyThreshold, isOn: notifyBinding)
                Toggle(L10n.settingsNetworkOnly, isOn: networkOnlyBinding)
            }

            CLIPathSettingsSection()

            CLIInstallSettingsSection(store: store)
        }
        .formStyle(.grouped)
    }

    private var notifyBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.bool(forKey: "notifyOnThreshold") },
            set: { enabled in
                UserDefaults.standard.set(enabled, forKey: "notifyOnThreshold")
                if enabled {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
                }
            }
        )
    }

    private var networkOnlyBinding: Binding<Bool> {
        Binding(
            get: { UserDefaults.standard.object(forKey: "refreshOnlyOnNetwork") as? Bool ?? true },
            set: { UserDefaults.standard.set($0, forKey: "refreshOnlyOnNetwork") }
        )
    }
}

// MARK: - CLI Path (FR-7)

/// 自定义 `codex-auth` 可执行文件路径:覆盖内置/PATH 发现,含校验与访达定位。
private struct CLIPathSettingsSection: View {
    @AppStorage("codexAuthPath") private var cliPath: String = ""
    @State private var validationMessage: String?

    var body: some View {
        Section {
            TextField(L10n.settingsCliPathPlaceholder, text: $cliPath)
                .onChange(of: cliPath) { _, newValue in
                    validate(newValue)
                    // 路径变化后能力探测缓存失效,下次变更命令前重新探测。
                    Task { await CLIProcessService.shared.resetCapabilities() }
                }
                .onAppear { validate(cliPath) }

            if let message = validationMessage {
                Text(message)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.statusOrange)
            }

            HStack {
                Button(L10n.settingsCliPathReveal) { reveal() }
                Button(L10n.settingsCliPathClear) {
                    cliPath = ""
                    validationMessage = nil
                }
            }
        } header: {
            Text(L10n.settingsCliPath)
        } footer: {
            Text(L10n.settingsCliPathNote)
        }
    }

    private func validate(_ path: String) {
        guard !path.isEmpty else {
            validationMessage = nil
            return
        }
        validationMessage = FileManager.default.isExecutableFile(atPath: path)
            ? nil
            : L10n.settingsCliPathInvalid
    }

    private func reveal() {
        let target: String
        if cliPath.isEmpty {
            target = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex").path
        } else {
            target = (cliPath as NSString).deletingLastPathComponent
        }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: target)])
    }
}

// MARK: - Language

private struct LanguageView: View {
    @Binding var language: String

    var body: some View {
        Form {
            Section {
                Picker(L10n.settingsLanguage, selection: $language) {
                    Text(L10n.settingsLangSystem).tag("system")
                    Text("English").tag("en")
                    Text("简体中文").tag("zh")
                }
                .pickerStyle(.radioGroup)
            }

            Section {
                Text(L10n.settingsLangNote)
                    .font(AppTypography.caption)
                    .foregroundStyle(StitchColor.onSurfaceVariant)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - About

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "diamond")
                .font(.system(size: 48))
                .foregroundStyle(StitchColor.primaryContainer.gradient)

            Text(L10n.settingsAboutTitle)
                .font(.title2)
                .foregroundStyle(StitchColor.onSurface)

            Text(L10n.settingsAboutSubtitle)
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.onSurfaceVariant)

            Text(L10n.settingsVersion)
                .font(AppTypography.caption)
                .foregroundStyle(StitchColor.outline)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView(store: MenuBarStore())
}
