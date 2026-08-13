import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class MenuBarStore {
    // MARK: - State

    var accounts: [CodexAccount] = []
    var isRefreshing = false
    var switchingAccountID: CodexAccount.ID?
    var removingAccountID: CodexAccount.ID?
    var errorMessage: String?
    var lastSyncTime: Date?

    /// 非阻塞提示(切换后需重启客户端、活跃账号被移除等);下次刷新开始时清除。
    var noticeMessage: String?

    /// `state_uncertain` 锁定:true 时禁用所有变更操作,直到下一次 list 成功。
    var mutationsLocked = false

    /// 能力探测结果(nil = 未探测或探测失败);变更命令在服务层 fail-closed。
    private(set) var capabilities: CLICapabilities?

    /// 首次 API 刷新前的隐私披露是否已确认。
    var privacyDisclosurePending = false

    /// Non-nil when confirm-before-switch dialog should show.
    var pendingSwitchAccount: CodexAccount?

    /// Non-nil when the remove confirmation dialog should show.
    var pendingRemoveAccount: CodexAccount?

    /// 别名编辑 sheet 的呈现账户;`aliasSheetMessage` 为 CLI 结构化校验错误。
    var aliasSheetAccount: CodexAccount?
    var aliasSheetMessage: String?

    /// 导入/导出 sheet 的呈现状态与最近结果。
    var showImportSheet = false
    var showExportSheet = false
    var lastImportSummary: CLIImportResponse?
    var lastExportSummary: CLIExportResponse?
    var managementBusy = false

    /// device-auth 登录流状态(FR-11)。
    var showLoginSheet = false
    var loginState: LoginFlowState = .idle

    /// CLI 安装/更新向导状态(PRD Section 13)。
    var cliInstallInfo: CLIInstallInfo?
    var cliInstallMessage: String?
    var showCLIInstallWizard = false

    /// Codex App 启动结果(FR-12)。
    var lastAppLaunchStatus: String?

    /// P4:维护操作结果与 live 间隔配置。
    var lastCleanSummary: CLICleanResponse?
    var liveIntervalSeconds: Int?
    private var lastThresholdNotificationKey: String?

    private var loginCancellation = LoginCancellationFlag()
    private var cliInstaller: CLIInstaller
    /// 登录会话代际:每次 present 递增;旧会话的迟到相位回调被忽略(S2 竞态)。
    private var loginSessionID = UUID()
    private var isLoginRunning = false

    init(cli: CLIProcessService = .shared, installer: CLIInstaller = .shared) {
        self.cli = cli
        self.cliInstaller = installer
    }

    private var activeAccountKey: String?
    private let cli: CLIProcessService

    var activeAccount: CodexAccount? {
        if let key = activeAccountKey {
            return accounts.first(where: { $0.id == key })
        }
        return accounts.first(where: \.isActive)
    }

    var inactiveAccounts: [CodexAccount] {
        accounts.filter { $0.id != activeAccount?.id }
    }

    private var needsPrivacyDisclosure: Bool {
        !UserDefaults.standard.bool(forKey: "apiRefreshDisclosureShown")
    }

    /// Whether the user wants a confirmation dialog before switching.
    private var confirmBeforeSwitch: Bool {
        UserDefaults.standard.bool(forKey: "confirmBeforeSwitch")
    }

    // MARK: - Refresh

    /// 拉取账户列表。`skipAPI` 为 true 时走 `--skip-api`(local-only,数据可能滞后)。
    ///
    /// 隐私披露只在**用户主动触发**的 API 刷新(`userInitiated`)前展示;
    /// 启动/周期后台刷新静默跳过 API,避免每 5 分钟重复弹出披露。
    func refresh(skipAPI: Bool = false, userInitiated: Bool = false) async {
        guard !isRefreshing else { return }
        if !skipAPI && userInitiated && needsPrivacyDisclosure {
            privacyDisclosurePending = true
            return
        }
        if !skipAPI && !userInitiated && needsPrivacyDisclosure {
            return
        }
        privacyDisclosurePending = false

        isRefreshing = true
        errorMessage = nil
        noticeMessage = nil
        defer { isRefreshing = false }

        let service = cli
        do {
            let response = try await Task.detached {
                try await service.executeList(skipAPI: skipAPI)
            }.value
            apply(response)
            mutationsLocked = false
            if !skipAPI {
                UserDefaults.standard.set(true, forKey: "apiRefreshDisclosureShown")
            }
            maybeNotifyThresholdCrossing()
        } catch {
            handle(error)
        }
    }

    func acceptPrivacyDisclosure() {
        UserDefaults.standard.set(true, forKey: "apiRefreshDisclosureShown")
    }

    func declinePrivacyDisclosure() {
        privacyDisclosurePending = false
    }

    /// 启动时探测 CLI 能力(变更命令据此 fail-closed)。
    func loadCapabilities() async {
        let service = cli
        capabilities = await Task.detached { await service.capabilities() }.value
    }

    // MARK: - Switch

    /// Requests a switch. If confirmation is enabled, sets `pendingSwitchAccount`
    /// so the UI can show a dialog; otherwise switches immediately.
    func requestSwitch(to account: CodexAccount) {
        if confirmBeforeSwitch {
            pendingSwitchAccount = account
        } else {
            Task { await switchAccount(to: account) }
        }
    }

    /// Confirms the pending switch.
    func confirmSwitch() {
        guard let account = pendingSwitchAccount else { return }
        pendingSwitchAccount = nil
        Task { await switchAccount(to: account) }
    }

    /// Cancels the pending switch dialog.
    func cancelSwitch() {
        pendingSwitchAccount = nil
    }

    func switchAccount(to account: CodexAccount) async {
        guard switchingAccountID == nil, !mutationsLocked else { return }
        switchingAccountID = account.id
        defer { switchingAccountID = nil }

        let service = cli
        var didSwitch = false
        do {
            let switched = try await Task.detached {
                try await service.executeSwitch(accountKey: account.id)
            }.value
            applySwitched(switched)
            didSwitch = true
            await refresh(skipAPI: true, userInitiated: true)
            noticeMessage = L10n.noticeSwitchRestart
        } catch {
            // 切换已成功但随后的 list 失败:提示仍需展示(FR-4),错误作为次要说明。
            if didSwitch { noticeMessage = L10n.noticeSwitchRestart }
            handle(error)
        }
    }

    // MARK: - Remove

    func requestRemove(_ account: CodexAccount) {
        pendingRemoveAccount = account
    }

    func confirmRemove() {
        guard let account = pendingRemoveAccount else { return }
        pendingRemoveAccount = nil
        Task { await removeAccount(account) }
    }

    func cancelRemove() {
        pendingRemoveAccount = nil
    }

    func removeAccount(_ account: CodexAccount) async {
        guard removingAccountID == nil, !mutationsLocked else { return }
        removingAccountID = account.id
        defer { removingAccountID = nil }

        let service = cli
        var didRemove = false
        var activeChanged = false
        do {
            let response = try await Task.detached {
                try await service.executeRemove(accountKey: account.id)
            }.value
            let previousActive = activeAccountKey
            if let newActive = response.newActiveAccountKey {
                activeAccountKey = newActive
                activeChanged = newActive != previousActive
            }
            didRemove = true
            await refresh(skipAPI: true, userInitiated: true)
            if activeChanged {
                noticeMessage = L10n.noticeActiveChanged
            }
        } catch {
            // 移除已成功但随后的 list 失败:活跃变更提示仍需展示(FR-5)。
            if didRemove, activeChanged { noticeMessage = L10n.noticeActiveChanged }
            handle(error)
        }
    }

    /// 本地已装版本比内置新(语义比较):安装前 UI 需展示两版本确认(B1)。
    var cliInstallNeedsDowngradeConfirmation: Bool {
        guard let installed = cliInstallInfo?.installedVersion,
              let bundled = cliInstallInfo?.bundledVersion else { return false }
        return CLIInstaller.isVersion(installed, newerThan: bundled)
    }

    /// 向导消息:展示内置/已装版本(PRD 13.3)。
    var cliInstallWizardMessageText: String {
        if let installed = cliInstallInfo?.installedVersion,
           let bundled = cliInstallInfo?.bundledVersion {
            return L10n.cliInstallWizardMessageVersions(bundled, installed)
        }
        return L10n.cliInstallWizardMessage
    }

    /// 变更命令的 UI 级门控(FR-13):能力未知时允许点击(服务层 fail-closed),
    /// 已知不支持时提前禁用菜单项。
    var supportsSwitchCommand: Bool {
        capabilities?.supports("switch") ?? true
    }

    var supportsRemoveCommand: Bool {
        capabilities?.supports("remove") ?? true
    }

    var supportsAliasCommand: Bool {
        capabilities?.supports("alias") ?? true
    }

    // MARK: - Alias (FR-8)

    func presentAliasSheet(for account: CodexAccount) {
        aliasSheetMessage = nil
        aliasSheetAccount = account
    }

    func dismissAliasSheet() {
        aliasSheetAccount = nil
        aliasSheetMessage = nil
    }

    /// 客户端预校验(与 CLI 规则一致:非空、非全数字、无控制字符)后执行 `alias set --json`。
    func setAlias(_ rawAlias: String, for account: CodexAccount) async {
        let alias = rawAlias.trimmingCharacters(in: .whitespacesAndNewlines)
        if let violation = Self.aliasPreValidationViolation(alias) {
            aliasSheetMessage = violation
            return
        }
        guard !mutationsLocked else { return }

        let service = cli
        do {
            _ = try await Task.detached {
                try await service.executeAliasSet(accountKey: account.id, alias: alias)
            }.value
            aliasSheetMessage = nil
            aliasSheetAccount = nil
            await refresh(skipAPI: true, userInitiated: true)
        } catch {
            handleAliasError(error)
        }
    }

    func clearAlias(for account: CodexAccount) async {
        guard !mutationsLocked else { return }
        let service = cli
        do {
            _ = try await Task.detached {
                try await service.executeAliasClear(accountKey: account.id)
            }.value
            aliasSheetMessage = nil
            aliasSheetAccount = nil
            await refresh(skipAPI: true, userInitiated: true)
        } catch {
            handleAliasError(error)
        }
    }

    /// 返回违规文案;nil 表示通过。规则与 CLI 校验一致。
    static func aliasPreValidationViolation(_ alias: String) -> String? {
        if alias.isEmpty { return L10n.aliasInvalidEmpty }
        if alias.allSatisfy(\.isNumber) { return L10n.aliasInvalidDigits }
        if alias.contains(where: { $0.asciiValue.map { $0 < 0x20 || $0 == 0x7f } ?? false }) {
            return L10n.aliasInvalidControl
        }
        return nil
    }

    private func handleAliasError(_ error: Error) {
        if let cliError = error as? CLIError,
           case .structured(let code, let message) = cliError,
           code == "invalid_alias" || code == "duplicate_alias" {
            aliasSheetMessage = message
            return
        }
        handle(error)
    }

    // MARK: - Import / Export (FR-9 / FR-10)

    func presentImportSheet() {
        lastImportSummary = nil
        showImportSheet = true
    }

    func presentExportSheet() {
        lastExportSummary = nil
        showExportSheet = true
    }

    func runImport(path: String?, alias: String?, mode: ImportMode) async {
        guard !managementBusy else { return }
        managementBusy = true
        defer { managementBusy = false }
        lastImportSummary = nil

        let service = cli
        do {
            let response = try await Task.detached {
                try await service.executeImport(path: path, alias: alias, mode: mode)
            }.value
            lastImportSummary = response
            await refresh(skipAPI: true, userInitiated: true)
        } catch {
            handle(error)
        }
    }

    func runExport(destination: String?, format: ExportFormat) async {
        guard !managementBusy else { return }
        managementBusy = true
        defer { managementBusy = false }
        lastExportSummary = nil

        let service = cli
        do {
            let response = try await Task.detached {
                try await service.executeExport(destination: destination, format: format)
            }.value
            lastExportSummary = response
        } catch {
            handle(error)
        }
    }

    /// 导入后是否需要收敛列表(标准/CPA 导入不改变活跃行,但行集会变化)。
    var importSucceeded: Bool {
        lastImportSummary != nil
    }

    // MARK: - Login (FR-11)

    func presentLoginSheet() {
        // 旧流作废:取消 + 代际递增,旧相位回调不再影响新 sheet。
        loginCancellation.cancel()
        loginSessionID = UUID()
        loginCancellation = LoginCancellationFlag()
        loginState = .idle
        showLoginSheet = true
    }

    func dismissLoginSheet() {
        loginCancellation.cancel()
        loginSessionID = UUID()
        showLoginSheet = false
        if case .awaitingUser = loginState { loginState = .idle }
    }

    func startLogin() async {
        guard !isLoginRunning else { return }
        isLoginRunning = true
        defer { isLoginRunning = false }
        loginState = .finishing
        let service = cli
        let cancellation = loginCancellation
        let sessionID = loginSessionID
        do {
            _ = try await Task.detached {
                try await service.executeLoginDeviceAuth(
                    isCancelled: { cancellation.isCancelled },
                    onPhase: { [weak self] document in
                        Task { @MainActor [weak self] in
                            self?.applyLoginPhase(document, sessionID: sessionID)
                        }
                    }
                )
            }.value
        } catch {
            guard sessionID == loginSessionID else { return }
            loginState = .failed(message: error.localizedDescription)
        }
    }

    /// 登录流结束后的收尾:completed 时收敛列表并关闭 sheet。
    private func applyLoginPhase(_ document: CLILoginPhaseDocument, sessionID: UUID) {
        // 旧会话的迟到回调直接忽略(新 sheet 已 reset 代际)。
        guard sessionID == loginSessionID else { return }
        switch document.phase {
        case "awaiting_user":
            loginState = .awaitingUser(
                verificationURL: document.verificationUrl ?? "",
                userCode: document.userCode ?? ""
            )
        case "completed":
            loginState = .completed
            showLoginSheet = false
            Task { await refresh(skipAPI: true, userInitiated: true) }
        case "failed":
            loginState = .failed(message: document.message ?? L10n.loginFailedGeneric)
        default:
            break
        }
    }

    /// Terminal 回退:在 Terminal.app 中运行交互式 `codex-auth login`,
    /// 使用解析到的 CLI 路径(不依赖 PATH);用户返回时弹窗重开即刷新。
    func openTerminalLoginFallback() async {
        let cliPath = await CLIProcessService.shared.resolvePath() ?? "codex-auth"
        let escaped = cliPath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"Terminal\" to do script \"\(escaped) login\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        try? task.run()
    }

    func copyLoginCode() {
        guard case .awaitingUser(_, let code) = loginState else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(code, forType: .string)
    }

    func openLoginVerificationURL() {
        guard case .awaitingUser(let url, _) = loginState,
              let verificationURL = URL(string: url) else { return }
        NSWorkspace.shared.open(verificationURL)
    }

    // MARK: - Launch Codex App (FR-12)

    func launchCodexApp() async {
        let service = cli
        do {
            let response = try await Task.detached {
                try await service.executeAppLaunch()
            }.value
            lastAppLaunchStatus = response.status == "already_running"
                ? L10n.appLaunchAlreadyRunning
                : L10n.appLaunchLaunched
        } catch {
            handle(error)
        }
    }

    // MARK: - Switch to Previous (PRD Section 10)

    /// `switch --previous --json`:切回上一个活跃账号,成功后展示重启提示。
    func switchToPrevious() async {
        guard switchingAccountID == nil, !mutationsLocked else { return }
        let service = cli
        do {
            let switched = try await Task.detached {
                try await service.executeSwitchPrevious()
            }.value
            applySwitched(switched)
            await refresh(skipAPI: true, userInitiated: true)
            noticeMessage = L10n.noticeSwitchRestart
        } catch {
            handle(error)
        }
    }

    // MARK: - Maintenance (clean / config)

    /// 清理 accounts/ 下的备份与过期文件,结果写入 `lastCleanSummary`。
    func cleanBackups() async {
        guard !managementBusy else { return }
        managementBusy = true
        defer { managementBusy = false }
        lastCleanSummary = nil

        let service = cli
        do {
            lastCleanSummary = try await Task.detached {
                try await service.executeClean()
            }.value
        } catch {
            handle(error)
        }
    }

    /// 读取 CLI 的 live TUI 刷新间隔。
    func loadLiveInterval() async {
        let service = cli
        do {
            liveIntervalSeconds = try await Task.detached {
                try await service.executeConfigGet()
            }.value.intervalSeconds
        } catch {
            // 配置读取失败不打断主流程,静默保留旧值。
        }
    }

    /// 写入 CLI 的 live TUI 刷新间隔(5–3600)。
    func setLiveInterval(_ interval: Int) async {
        let service = cli
        do {
            liveIntervalSeconds = try await Task.detached {
                try await service.executeConfigSetLiveInterval(interval)
            }.value.intervalSeconds
        } catch {
            handle(error)
        }
    }

    // MARK: - Threshold Notification (PRD Section 10)

    /// 刷新后检查活跃账号是否跌破阈值;开启通知且状态变化时通知一次。
    func maybeNotifyThresholdCrossing() {
        guard UserDefaults.standard.bool(forKey: "notifyOnThreshold") else { return }
        guard let usage = activeAccount?.primaryUsage else { return }
        let threshold = UserDefaults.standard.double(forKey: "lowCapacityThreshold")
        let thresholdValue = threshold > 0 ? threshold : 20
        let below = usage.remainingPercent < thresholdValue

        let key = "\(activeAccount?.id ?? "none")-\(below ? "below" : "ok")"
        guard key != lastThresholdNotificationKey else { return }
        lastThresholdNotificationKey = key
        guard below else { return }

        NotificationCenter.default.post(
            name: .codexSwitcherThresholdCrossed,
            object: nil,
            userInfo: ["account": activeAccount?.alias ?? "", "remaining": Int(usage.remainingPercent)]
        )
    }

    // MARK: - CLI Install / Update (PRD Section 13)

    func loadCLIInstallInfo() async {
        cliInstallInfo = await cliInstaller.detect()
    }

    /// 首次启动/更新后:内置版本与上次安装记录不一致时武装向导。
    func checkCLIInstallWizard() async {
        await loadCLIInstallInfo()
        guard let bundledVersion = cliInstallInfo?.bundledVersion else { return }
        let last = UserDefaults.standard.string(forKey: "lastCliInstallBundledVersion")
        if last != bundledVersion {
            showCLIInstallWizard = true
        }
    }

    func skipCLIInstallWizard() {
        showCLIInstallWizard = false
        recordCLIInstallVersion()
    }

    func acceptCLIInstallWizard() {
        showCLIInstallWizard = false
        Task { await installOrUpdateCLI() }
    }

    func installOrUpdateCLI() async {
        let info = cliInstallInfo
        do {
            try await cliInstaller.install(targetDirectory: info?.targetDirectory)
            recordCLIInstallVersion()
            await loadCLIInstallInfo()
            cliInstallMessage = L10n.cliInstallSuccess
        } catch {
            cliInstallMessage = error.localizedDescription
        }
    }

    private func recordCLIInstallVersion() {
        if let bundledVersion = cliInstallInfo?.bundledVersion {
            UserDefaults.standard.set(bundledVersion, forKey: "lastCliInstallBundledVersion")
        }
    }

    // MARK: - Copy Email

    func copyEmail(_ account: CodexAccount) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(account.email, forType: .string)
    }

    // MARK: - Internals

    private func apply(_ response: CLIListResponse) {
        accounts = AccountMapper.map(response)
        activeAccountKey = response.activeAccountKey
        lastSyncTime = .now
    }

    /// 用 `switched_to` 就地更新活跃标记,再等 list 收敛(FR-4)。
    private func applySwitched(_ switched: CLIAccount) {
        activeAccountKey = switched.accountKey
        accounts = accounts.map { account in
            var updated = account
            updated.isActive = account.id == switched.accountKey
            return updated
        }
    }

    private func handle(_ error: Error) {
        if let cliError = error as? CLIError {
            if cliError.isStateUncertain {
                mutationsLocked = true
            }
            errorMessage = cliError.errorDescription
            return
        }
        errorMessage = error.localizedDescription
    }
}

// MARK: - Login Flow State

/// device-auth 登录流状态机(FR-11)。
enum LoginFlowState: Equatable, Sendable {
    case idle
    /// 已向 CLI 发出请求,等待相位文档。
    case finishing
    /// 已捕获设备码:展示 URL + 码,等待用户在浏览器完成。
    case awaitingUser(verificationURL: String, userCode: String)
    case completed
    case failed(message: String)
}

/// 跨线程的登录取消标志(后台流式读取与 MainActor 状态之间的通道)。
final class LoginCancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    func reset() {
        lock.lock()
        cancelled = false
        lock.unlock()
    }
}

extension Notification.Name {
    /// 活跃账号剩余容量跌破阈值(通知开关开启时)。
    static let codexSwitcherThresholdCrossed = Notification.Name("codexSwitcher.thresholdCrossed")
}
