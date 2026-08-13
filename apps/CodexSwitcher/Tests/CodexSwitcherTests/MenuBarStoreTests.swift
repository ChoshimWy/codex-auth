import XCTest
@testable import CodexSwitcher

@MainActor
final class MenuBarStoreTests: XCTestCase {
    private var runner: FakeCLIProcessRunner!

    override func setUp() {
        super.setUp()
        runner = FakeCLIProcessRunner()
        UserDefaults.standard.set(true, forKey: "apiRefreshDisclosureShown")
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: "apiRefreshDisclosureShown")
        runner = nil
        super.tearDown()
    }

    private func makeStore(cliInstaller: CLIInstaller = .shared) -> MenuBarStore {
        MenuBarStore(
            cli: CLIProcessService(
                pathProvider: { "/fake/codex-auth" },
                runner: runner
            ),
            installer: cliInstaller
        )
    }

    private let probeJSON = """
    {"schema_version":1,"command":"version","version":"0.3.0-alpha.10","json_api_schema":1,"supported_commands":["list","switch","remove","alias","import","export","app","login","clean","config"]}
    """

    private func listJSON(activeKey: String, emails: [String]) -> String {
        let accounts = emails.enumerated().map { index, email in
            let key = "key-\(email)"
            return """
            {"number":\(index + 1),"account_key":"\(key)","email":"\(email)","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":\(key == activeKey),"created_at":1730000000,"last_used_at":1730001000,"usage":null}
            """
        }.joined(separator: ",")
        return """
        {"schema_version":1,"command":"list","active_account_key":"\(activeKey)","accounts":[\(accounts)]}
        """
    }

    private func switchJSON(email: String) -> String {
        """
        {"schema_version":1,"command":"switch","switched_to":{"number":2,"account_key":"key-\(email)","email":"\(email)","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
        """
    }

    private func removeJSON(removedEmail: String, newActiveEmail: String?) -> String {
        let removed = """
        [{"number":1,"account_key":"key-\(removedEmail)","email":"\(removedEmail)","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":false,"created_at":1730000000,"last_used_at":1730001000,"usage":null}]
        """
        let newActive = newActiveEmail.map { "\"key-\($0)\"" } ?? "null"
        return """
        {"schema_version":1,"command":"remove","removed":\(removed),"new_active_account_key":\(newActive)}
        """
    }

    // MARK: - Refresh

    func testRefreshAppliesAccountsAndUnlocksMutations() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()

        store.mutationsLocked = true
        await store.refresh()

        XCTAssertEqual(store.accounts.count, 1)
        XCTAssertEqual(store.activeAccount?.id, "key-a@example.com")
        XCTAssertFalse(store.mutationsLocked)
        XCTAssertNotNil(store.lastSyncTime)
    }

    func testStateUncertainLocksMutationsUntilSuccessfulList() async {
        runner.enqueue(stdout: """
        {"schema_version":1,"error":{"code":"state_uncertain","message":"persistence failed"}}
        """, exitCode: 1)
        let store = makeStore()

        await store.refresh()
        XCTAssertTrue(store.mutationsLocked)
        XCTAssertEqual(store.errorMessage, L10n.cliStateUncertain)

        // 成功 list 解锁
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        await store.refresh()
        XCTAssertFalse(store.mutationsLocked)
    }

    func testPrivacyDisclosureGatesFirstAPIRefresh() async {
        UserDefaults.standard.removeObject(forKey: "apiRefreshDisclosureShown")
        let store = makeStore()

        // 后台/启动刷新:静默跳过,不武装弹窗、不发请求
        await store.refresh()
        XCTAssertFalse(store.privacyDisclosurePending)
        XCTAssertEqual(runner.invocations(for: "list").count, 0)

        // 用户主动 API 刷新:武装披露弹窗
        await store.refresh(userInitiated: true)
        XCTAssertTrue(store.privacyDisclosurePending)
        XCTAssertEqual(runner.invocations(for: "list").count, 0)

        // local-only 不需要披露
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        await store.refresh(skipAPI: true, userInitiated: true)
        XCTAssertEqual(runner.invocations(for: "list"), [["list", "--skip-api", "--json"]])

        // 接受披露后 API 刷新恢复
        store.acceptPrivacyDisclosure()
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        await store.refresh(userInitiated: true)
        XCTAssertEqual(runner.invocations(for: "list").last, ["list", "--json"])
    }

    // MARK: - Switch

    func testSwitchAppliesSwitchedToAndShowsRestartNotice() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let target = store.accounts.first(where: { $0.email == "b@example.com" }) else {
            return XCTFail("target account missing")
        }

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: switchJSON(email: "b@example.com"))
        runner.enqueue(stdout: listJSON(activeKey: "key-b@example.com", emails: ["a@example.com", "b@example.com"]))

        await store.switchAccount(to: target)

        XCTAssertEqual(store.activeAccount?.id, "key-b@example.com")
        XCTAssertEqual(store.noticeMessage, L10n.noticeSwitchRestart)
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - Remove

    func testRemoveRefreshesAndAnnouncesActiveChange() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let target = store.accounts.first(where: { $0.email == "a@example.com" }) else {
            return XCTFail("target account missing")
        }

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: removeJSON(removedEmail: "a@example.com", newActiveEmail: "b@example.com"))
        runner.enqueue(stdout: listJSON(activeKey: "key-b@example.com", emails: ["b@example.com"]))

        store.requestRemove(target)
        store.confirmRemove()
        // confirmRemove 内部 Task 异步执行,轮询等待完成
        await waitUntil { store.removingAccountID == nil && store.accounts.count == 1 }

        XCTAssertEqual(store.accounts.count, 1)
        XCTAssertEqual(store.activeAccount?.id, "key-b@example.com")
        XCTAssertEqual(store.noticeMessage, L10n.noticeActiveChanged)
    }

    func testRemoveWithoutNewActiveKeepsActiveKey() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let target = store.accounts.first(where: { $0.email == "b@example.com" }) else {
            return XCTFail("target account missing")
        }

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: removeJSON(removedEmail: "b@example.com", newActiveEmail: nil))
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))

        store.requestRemove(target)
        store.confirmRemove()
        await waitUntil { store.removingAccountID == nil && store.accounts.count == 1 }

        XCTAssertEqual(store.activeAccount?.id, "key-a@example.com")
        XCTAssertNil(store.noticeMessage)
    }

    func testSwitchStateUncertainLocksMutations() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let target = store.accounts.first(where: { $0.email == "b@example.com" }) else {
            return XCTFail("target account missing")
        }

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"error":{"code":"state_uncertain","message":"the switch operation could not be completed"}}
        """, exitCode: 1)

        await store.switchAccount(to: target)

        XCTAssertTrue(store.mutationsLocked)
        XCTAssertEqual(store.errorMessage, L10n.cliStateUncertain)
        // 活跃标记不变
        XCTAssertEqual(store.activeAccount?.id, "key-a@example.com")
    }

    func testSwitchFailureLeavesStateClean() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let target = store.accounts.first(where: { $0.email == "b@example.com" }) else {
            return XCTFail("target account missing")
        }

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"error":{"code":"account_not_found","message":"no account matches"}}
        """, exitCode: 1)

        await store.switchAccount(to: target)

        XCTAssertFalse(store.mutationsLocked)
        XCTAssertEqual(store.errorMessage, "no account matches")
        XCTAssertEqual(store.activeAccount?.id, "key-a@example.com")
        XCTAssertNil(store.noticeMessage)
    }

    func testSwitchSuccessKeepsRestartNoticeWhenRefreshFails() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let target = store.accounts.first(where: { $0.email == "b@example.com" }) else {
            return XCTFail("target account missing")
        }

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: switchJSON(email: "b@example.com"))
        runner.enqueue(stdout: "", exitCode: 1)   // 随后的 list 失败

        await store.switchAccount(to: target)

        XCTAssertEqual(store.noticeMessage, L10n.noticeSwitchRestart)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.activeAccount?.id, "key-b@example.com")
    }

    func testRefreshFailurePreservesPreviousSnapshot() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()
        await store.refresh()
        XCTAssertEqual(store.accounts.count, 1)
        let previousSync = store.lastSyncTime

        runner.enqueue(stdout: "not json", exitCode: 1)
        await store.refresh()

        // FR-6:刷新失败保留上一有效快照
        XCTAssertEqual(store.accounts.count, 1)
        XCTAssertEqual(store.activeAccount?.id, "key-a@example.com")
        XCTAssertEqual(store.lastSyncTime, previousSync)
        XCTAssertNotNil(store.errorMessage)
    }

    // MARK: - Alias

    func testAliasPreValidationMatchesCliRules() {
        // 注意:setAlias 先 trim;静态校验接收 trim 后的值。
        XCTAssertNotNil(MenuBarStore.aliasPreValidationViolation(""))
        XCTAssertNotNil(MenuBarStore.aliasPreValidationViolation("123"))
        XCTAssertNotNil(MenuBarStore.aliasPreValidationViolation("a\u{07}b"))
        XCTAssertNil(MenuBarStore.aliasPreValidationViolation("work"))
        XCTAssertNil(MenuBarStore.aliasPreValidationViolation("work-1"))
    }

    func testSetAliasRefreshesAndClearsSheet() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()
        await store.refresh()
        store.presentAliasSheet(for: store.accounts[0])

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"alias","operation":"set","updated":{"number":1,"account_key":"key-a@example.com","email":"a@example.com","alias":"work","account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
        """)
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))

        await store.setAlias("work", for: store.accounts[0])

        XCTAssertNil(store.aliasSheetAccount)
        XCTAssertNil(store.aliasSheetMessage)
        XCTAssertEqual(runner.invocations(for: "alias").first, ["alias", "set", "key-a@example.com", "work", "--json"])
    }

    func testSetAliasShowsStructuredValidationInline() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()
        store.presentAliasSheet(for: store.accounts[0])

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"error":{"code":"duplicate_alias","message":"alias 'work' is already used by b@example.com"}}
        """, exitCode: 1)

        await store.setAlias("work", for: store.accounts[0])

        // 内联错误保留在 sheet 中,不污染全局错误
        XCTAssertEqual(store.aliasSheetMessage, "alias 'work' is already used by b@example.com")
        XCTAssertNotNil(store.aliasSheetAccount)
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - Import / Export

    func testRunImportConvergesListEvenWhenDisclosureNotAccepted() async {
        // B1 回归:全新安装、披露未确认时,导入后的收敛刷新走 local-only,不得被 gate 跳过。
        UserDefaults.standard.removeObject(forKey: "apiRefreshDisclosureShown")
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()
        await store.refresh(skipAPI: true, userInitiated: true)
        XCTAssertEqual(store.accounts.count, 1)

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"import","mode":"standard","source":"/tmp/token.json","results":[{"path":"token.json","status":"imported","email":null,"reason":null}],"imported_count":1,"updated_count":0,"skipped_count":0,"active_account_key":null}
        """)
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))

        await store.runImport(path: "/tmp/token.json", alias: nil, mode: .standard)

        XCTAssertEqual(store.lastImportSummary?.importedCount, 1)
        XCTAssertEqual(store.accounts.count, 2, "披露未确认时导入后列表也应收敛")
        XCTAssertFalse(store.privacyDisclosurePending)
    }

    func testRunImportStoresSummaryAndRefreshes() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()
        await store.refresh()

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"import","mode":"standard","source":"/tmp/token.json","results":[{"path":"token.json","status":"imported","email":null,"reason":null}],"imported_count":1,"updated_count":0,"skipped_count":0,"active_account_key":null}
        """)
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))

        await store.runImport(path: "/tmp/token.json", alias: nil, mode: .standard)

        XCTAssertEqual(store.lastImportSummary?.importedCount, 1)
        XCTAssertEqual(store.accounts.count, 2)
        XCTAssertEqual(runner.invocations(for: "import").first, ["import", "/tmp/token.json", "--json"])
    }

    func testRunExportStoresSummary() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()
        await store.refresh()

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"export","format":"standard","destination":"/tmp/backup","exported_count":1,"skipped_count":0}
        """)

        await store.runExport(destination: "/tmp/backup", format: .standard)

        XCTAssertEqual(store.lastExportSummary?.exportedCount, 1)
        XCTAssertEqual(store.lastExportSummary?.destination, "/tmp/backup")
        XCTAssertEqual(runner.invocations(for: "export").first, ["export", "/tmp/backup", "--json"])
    }

    // MARK: - Login

    func testLoginFlowTransitionsToAwaitingAndCompletes() async {
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"login","mode":"device_auth","phase":"awaiting_user","verification_url":"https://auth.openai.com/codex/device","user_code":"TEST-1234"}
        {"schema_version":1,"command":"login","mode":"device_auth","phase":"completed","active_account_key":"key-login","account":{"number":1,"account_key":"key-login","email":"login-json@example.com","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
        """)
        runner.enqueue(stdout: listJSON(activeKey: "key-login", emails: ["login-json@example.com"]))
        let store = makeStore()
        store.presentLoginSheet()

        await store.startLogin()

        XCTAssertEqual(store.loginState, .completed)
        XCTAssertFalse(store.showLoginSheet)
        // 登录后收敛:新账号出现在列表中
        await waitUntil { store.accounts.contains { $0.email == "login-json@example.com" } }
        XCTAssertTrue(store.accounts.contains { $0.email == "login-json@example.com" })
    }

    func testLoginFailedPhaseStaysOpenWithMessage() async {
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"login","mode":"device_auth","phase":"failed","message":"codex login failed with exit code 1"}
        """)
        let store = makeStore()
        store.presentLoginSheet()

        await store.startLogin()

        XCTAssertEqual(store.loginState, .failed(message: "codex login failed with exit code 1"))
        XCTAssertTrue(store.showLoginSheet)
    }

    // MARK: - Launch Codex App

    func testLaunchCodexAppReportsStatus() async {
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"app","status":"already_running","app_id":"com.openai.codex","codex_cli_path":null}
        """)
        let store = makeStore()

        await store.launchCodexApp()

        XCTAssertEqual(store.lastAppLaunchStatus, L10n.appLaunchAlreadyRunning)
        XCTAssertNil(store.errorMessage)
    }

    // MARK: - CLI Install Wizard

    func testCLIInstallWizardArmsOnVersionChange() async {
        UserDefaults.standard.removeObject(forKey: "lastCliInstallBundledVersion")
        let installer = CLIInstaller(
            runner: runner,
            bundledPathProvider: { "/fake/bundled/codex-auth" },
            installedPathResolver: { nil }
        )
        let store = makeStore(cliInstaller: installer)
        // 内置版本探测
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"version","version":"0.3.0-alpha.10","json_api_schema":1,"supported_commands":["list"]}
        """)

        await store.checkCLIInstallWizard()

        XCTAssertEqual(store.cliInstallInfo?.bundledVersion, "0.3.0-alpha.10")
        XCTAssertTrue(store.showCLIInstallWizard)

        store.skipCLIInstallWizard()
        XCTAssertEqual(
            UserDefaults.standard.string(forKey: "lastCliInstallBundledVersion"),
            "0.3.0-alpha.10"
        )

        // 再次检查:版本已记录,不再武装
        await store.checkCLIInstallWizard()
        XCTAssertFalse(store.showCLIInstallWizard)
    }

    // MARK: - Copy Email

    func testCopyEmailSetsPasteboard() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com"]))
        let store = makeStore()
        await store.refresh()

        guard let account = store.accounts.first else {
            return XCTFail("account missing")
        }
        store.copyEmail(account)

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), "a@example.com")
    }

    // MARK: - Helper

    /// 轮询等待异步条件成立(Store 内部 Task 完成后状态收敛)。
    private func waitUntil(
        timeout: TimeInterval = 2,
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("condition not met before timeout")
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}

// MARK: - P4 Extensions

extension MenuBarStoreTests {
    func testSwitchToPreviousAppliesSwitchedAndNotices() async {
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))
        let store = makeStore()
        await store.refresh()

        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: switchJSON(email: "a@example.com"))
        runner.enqueue(stdout: listJSON(activeKey: "key-a@example.com", emails: ["a@example.com", "b@example.com"]))

        await store.switchToPrevious()

        XCTAssertEqual(store.activeAccount?.id, "key-a@example.com")
        XCTAssertEqual(store.noticeMessage, L10n.noticeSwitchRestart)
        XCTAssertEqual(runner.invocations(for: "switch").first, ["switch", "--previous", "--json"])
    }

    func testCleanBackupsStoresSummary() async {
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"clean","target":"accounts","auth_backups_removed":1,"registry_backups_removed":0,"stale_snapshot_files_removed":0,"platform":null,"files_removed":null}
        """)
        let store = makeStore()

        await store.cleanBackups()

        XCTAssertEqual(store.lastCleanSummary?.authBackupsRemoved, 1)
        XCTAssertNil(store.errorMessage)
    }

    func testThresholdNotificationFiresOncePerCrossing() {
        UserDefaults.standard.set(true, forKey: "notifyOnThreshold")
        UserDefaults.standard.set(20.0, forKey: "lowCapacityThreshold")
        let store = makeStore()
        let counter = ThresholdCounter()
        let observer = NotificationCenter.default.addObserver(
            forName: .codexSwitcherThresholdCrossed,
            object: nil,
            queue: .main
        ) { _ in
            counter.increment()
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        // 通过 store 内部 apply 路径触发:直接调用 refresh 两次(脚本:低于阈值的列表)
        runner.enqueue(stdout: listWithUsageJSON(activeKey: "key-a@example.com", remaining: 10))
        let first = expectation(description: "first refresh")
        Task { await store.refresh(skipAPI: true, userInitiated: true); first.fulfill() }
        wait(for: [first], timeout: 2)

        runner.enqueue(stdout: listWithUsageJSON(activeKey: "key-a@example.com", remaining: 10))
        let second = expectation(description: "second refresh")
        Task { await store.refresh(skipAPI: true, userInitiated: true); second.fulfill() }
        wait(for: [second], timeout: 2)

        XCTAssertEqual(counter.count, 1, "同一状态只通知一次")

        UserDefaults.standard.removeObject(forKey: "notifyOnThreshold")
    }

    private func listWithUsageJSON(activeKey: String, remaining: Double) -> String {
        let used = 100 - remaining
        return """
        {"schema_version":1,"command":"list","active_account_key":"\(activeKey)","accounts":[{"number":1,"account_key":"\(activeKey)","email":"a@example.com","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":{"source":"cache","updated_at":1730002000,"primary":{"used_percent":\(used),"window_minutes":300,"resets_at":1730010000},"secondary":null,"credits":null,"reset_credits":null,"refresh":{"requested":false,"method":null,"status":"not_requested","http_status":null,"error_code":null}}}]}
        """
    }
}
