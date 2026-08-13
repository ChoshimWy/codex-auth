import XCTest
@testable import CodexSwitcher

final class CLIProcessServiceTests: XCTestCase {
    private func makeService(runner: FakeCLIProcessRunner) -> CLIProcessService {
        CLIProcessService(pathProvider: { "/fake/codex-auth" }, runner: runner)
    }

    // MARK: - Fixtures

    private let probeJSON = """
    {"schema_version":1,"command":"version","version":"0.3.0-alpha.10","json_api_schema":1,"supported_commands":["list","switch","remove","alias","import","export","app","login","clean","config"]}
    """

    private let listJSON = """
    {"schema_version":1,"command":"list","active_account_key":"key-a","accounts":[
      {"number":1,"account_key":"key-a","email":"a@example.com","alias":"work","account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,
       "usage":{"source":"cache","updated_at":1730002000,"primary":{"used_percent":12.5,"window_minutes":300,"resets_at":1730010000},"secondary":null,
                "credits":{"has_credits":false,"unlimited":false,"balance":null},"reset_credits":null,
                "refresh":{"requested":false,"method":null,"status":"not_requested","http_status":null,"error_code":null}}}
    ]}
    """

    private let stateUncertainJSON = """
    {"schema_version":1,"error":{"code":"state_uncertain","message":"the switch operation could not be completed"}}
    """

    private let switchJSON = """
    {"schema_version":1,"command":"switch","switched_to":{"number":2,"account_key":"key-b","email":"b@example.com","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
    """

    private let removeJSON = """
    {"schema_version":1,"command":"remove","removed":[{"number":1,"account_key":"key-a","email":"a@example.com","alias":"work","account_name":null,"plan":"plus","auth_mode":"chatgpt","active":false,"created_at":1730000000,"last_used_at":1730001000,"usage":null}],"new_active_account_key":"key-b"}
    """

    // MARK: - List

    func testListParsesValidDocumentAndValidatesSchema() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: listJSON)
        let service = makeService(runner: runner)

        let response = try await service.executeList()
        XCTAssertEqual(response.schemaVersion, 1)
        XCTAssertEqual(response.activeAccountKey, "key-a")
        XCTAssertEqual(response.accounts.count, 1)
        XCTAssertEqual(runner.invocations(for: "list").first, ["list", "--json"])
    }

    func testListLocalOnlyAppendsSkipAPI() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: listJSON)
        let service = makeService(runner: runner)

        _ = try await service.executeList(skipAPI: true)
        XCTAssertEqual(runner.invocations(for: "list").first, ["list", "--skip-api", "--json"])
    }

    func testListRejectsUnsupportedSchema() async {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: "{\"schema_version\":2,\"command\":\"list\",\"active_account_key\":null,\"accounts\":[]}")
        let service = makeService(runner: runner)

        await assertThrowsAsyncError {
            _ = try await service.executeList()
        } check: { error in
            XCTAssertEqual(error as? CLIError, .unsupportedSchema(2))
        }
    }

    func testListRejectsEmptyOutput() async {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: "")
        let service = makeService(runner: runner)

        await assertThrowsAsyncError {
            _ = try await service.executeList()
        } check: { error in
            XCTAssertEqual(error as? CLIError, .invalidOutput)
        }
    }

    // MARK: - Structured Errors

    func testStructuredErrorSurfacesCodeAndMessage() async {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: stateUncertainJSON, exitCode: 1)
        let service = makeService(runner: runner)

        await assertThrowsAsyncError {
            _ = try await service.executeList()
        } check: { error in
            guard let cliError = error as? CLIError,
                  case .structured(code: "state_uncertain", message: "the switch operation could not be completed") = cliError else {
                return XCTFail("expected structured state_uncertain, got \(error)")
            }
            XCTAssertTrue(cliError.isStateUncertain)
        }
    }

    func testExitCodeFailureWithoutErrorDocumentFallsBack() async {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: "not json", exitCode: 1)
        let service = makeService(runner: runner)

        await assertThrowsAsyncError {
            _ = try await service.executeList()
        } check: { error in
            XCTAssertEqual(error as? CLIError, .executionFailed(1))
        }
    }

    // MARK: - Capability Probe

    func testCapabilityProbeCachesAndFailsClosed() async throws {
        let runner = FakeCLIProcessRunner()
        // 能力列表只含 list:switch 变更必须 fail-closed
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"version","version":"0.3.0-alpha.10","json_api_schema":1,"supported_commands":["list"]}
        """)
        let service = makeService(runner: runner)

        let first = await service.capabilities()
        XCTAssertEqual(first?.supportedCommands, ["list"])
        let second = await service.capabilities()
        XCTAssertEqual(second, first)

        // 探测只执行一次(--version 只出现一次)
        XCTAssertEqual(runner.invocations(for: "--version").count, 1)

        await assertThrowsAsyncError {
            _ = try await service.executeSwitch(accountKey: "key-a")
        } check: { error in
            XCTAssertEqual(error as? CLIError, .missingCapability(command: "switch", version: "0.3.0-alpha.10"))
        }
    }

    func testCapabilityProbeFailureFailsClosed() async {
        let runner = FakeCLIProcessRunner()
        // 未预置结果:runner 抛 executionFailed → 探测失败
        let service = makeService(runner: runner)

        let capabilities = await service.capabilities()
        XCTAssertNil(capabilities)

        await assertThrowsAsyncError {
            _ = try await service.executeRemove(accountKey: "key-a")
        } check: { error in
            XCTAssertEqual(error as? CLIError, .missingCapability(command: "remove", version: nil))
        }
    }

    // MARK: - Switch

    func testSwitchDecodesSwitchedTo() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: switchJSON)
        let service = makeService(runner: runner)

        let switched = try await service.executeSwitch(accountKey: "key-b")
        XCTAssertEqual(switched.accountKey, "key-b")
        XCTAssertEqual(switched.email, "b@example.com")
        XCTAssertEqual(runner.invocations(for: "switch").first, ["switch", "key-b", "--json"])
    }

    // MARK: - Remove

    func testRemoveDecodesResponse() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: removeJSON)
        let service = makeService(runner: runner)

        let response = try await service.executeRemove(accountKey: "key-a")
        XCTAssertEqual(response.removed.count, 1)
        XCTAssertEqual(response.newActiveAccountKey, "key-b")
        XCTAssertEqual(runner.invocations(for: "remove").first, ["remove", "key-a", "--json"])
    }

    // MARK: - Alias

    func testAliasSetDecodesUpdatedAndValidatesCapability() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: aliasJSON)
        let service = makeService(runner: runner)

        let updated = try await service.executeAliasSet(accountKey: "key-a", alias: "work")
        XCTAssertEqual(updated.accountKey, "key-a")
        XCTAssertEqual(updated.alias, "work")
        XCTAssertEqual(runner.invocations(for: "alias").first, ["alias", "set", "key-a", "work", "--json"])
    }

    func testAliasClearDecodesUpdated() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"alias","operation":"clear","updated":{"number":1,"account_key":"key-a","email":"a@example.com","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
        """)
        let service = makeService(runner: runner)

        let updated = try await service.executeAliasClear(accountKey: "key-a")
        XCTAssertNil(updated.alias)
        XCTAssertEqual(runner.invocations(for: "alias").first, ["alias", "clear", "key-a", "--json"])
    }

    func testAliasStructuredValidationErrorSurfaces() async {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"error":{"code":"duplicate_alias","message":"alias 'work' is already used by b@example.com"}}
        """, exitCode: 1)
        let service = makeService(runner: runner)

        await assertThrowsAsyncError {
            _ = try await service.executeAliasSet(accountKey: "key-a", alias: "work")
        } check: { error in
            guard let cliError = error as? CLIError,
                  case .structured(code: "duplicate_alias", message: "alias 'work' is already used by b@example.com") = cliError else {
                return XCTFail("expected duplicate_alias, got \(error)")
            }
            XCTAssertFalse(cliError.isStateUncertain)
        }
    }

    // MARK: - Import / Export

    func testImportStandardBuildsArgumentsAndDecodes() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: importJSON)
        let service = makeService(runner: runner)

        let response = try await service.executeImport(path: "/tmp/token.json", alias: "work", mode: .standard)
        XCTAssertEqual(response.importedCount, 1)
        XCTAssertEqual(response.skippedCount, 1)
        XCTAssertEqual(response.results.first?.status, "imported")
        XCTAssertEqual(runner.invocations(for: "import").first, ["import", "/tmp/token.json", "--alias", "work", "--json"])
    }

    func testImportCpaAndPurgeArgumentShapes() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: importJSON)
        let service = makeService(runner: runner)

        _ = try await service.executeImport(path: nil, alias: nil, mode: .cpa)
        XCTAssertEqual(runner.invocations(for: "import").first, ["import", "--cpa", "--json"])

        runner.enqueue(stdout: purgeJSON)
        _ = try await service.executeImport(path: nil, alias: nil, mode: .purge)
        XCTAssertEqual(runner.invocations(for: "import").last, ["import", "--purge", "--json"])
        XCTAssertEqual(runner.invocations(for: "import").count, 2)
    }

    func testExportBuildsArgumentsAndDecodes() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: exportJSON)
        let service = makeService(runner: runner)

        let response = try await service.executeExport(destination: "/tmp/backup", format: .cpa)
        XCTAssertEqual(response.exportedCount, 2)
        XCTAssertEqual(response.skippedCount, 1)
        XCTAssertEqual(runner.invocations(for: "export").first, ["export", "/tmp/backup", "--cpa", "--json"])
    }

    // MARK: - Alias Fixture

    private let aliasJSON = """
    {"schema_version":1,"command":"alias","operation":"set","updated":{"number":1,"account_key":"key-a","email":"a@example.com","alias":"work","account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
    """

    private let importJSON = """
    {"schema_version":1,"command":"import","mode":"standard","source":"/tmp/token.json","results":[{"path":"token.json","status":"imported","email":null,"reason":null},{"path":"broken.json","status":"skipped","email":null,"reason":"MissingEmail"}],"imported_count":1,"updated_count":0,"skipped_count":1,"active_account_key":null}
    """

    private let purgeJSON = """
    {"schema_version":1,"command":"import","mode":"purge","source":"~/.codex/accounts","results":[],"imported_count":0,"updated_count":0,"skipped_count":0,"active_account_key":null,"registry_rebuilt":true}
    """

    private let exportJSON = """
    {"schema_version":1,"command":"export","format":"cpa","destination":"/tmp/backup","exported_count":2,"skipped_count":1}
    """

    // MARK: - Login Streaming

    func testLoginStreamingEmitsAwaitingAndCompletedPhases() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: loginTwoPhaseJSON)
        let service = makeService(runner: runner)

        let phases = PhaseCollector()
        let finalPhase = try await service.executeLoginDeviceAuth(
            isCancelled: { false }
        ) { document in
            phases.append(document.phase)
        }

        XCTAssertEqual(phases.values, ["awaiting_user", "completed"])
        XCTAssertEqual(finalPhase?.phase, "completed")
        XCTAssertEqual(finalPhase?.account?.email, "login-json@example.com")
        XCTAssertEqual(runner.invocations(for: "login").first, ["login", "--device-auth", "--json"])
    }

    func testLoginStreamingFailedPhase() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"login","mode":"device_auth","phase":"failed","message":"codex login failed with exit code 1"}
        """)
        let service = makeService(runner: runner)

        let finalPhase = try await service.executeLoginDeviceAuth(
            isCancelled: { false }
        ) { _ in }

        XCTAssertEqual(finalPhase?.phase, "failed")
        XCTAssertEqual(finalPhase?.message, "codex login failed with exit code 1")
    }

    func testLoginStreamingErrorDocumentThrowsStructured() async {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"login","mode":"device_auth","phase":"awaiting_user","verification_url":"https://auth.openai.com/codex/device","user_code":"TEST-1234"}
        {"schema_version":1,"error":{"code":"state_uncertain","message":"persistence failed"}}
        """, exitCode: 1)
        let service = makeService(runner: runner)

        let phases = PhaseCollector()
        await assertThrowsAsyncError {
            _ = try await service.executeLoginDeviceAuth(
                isCancelled: { false }
            ) { document in
                phases.append(document.phase)
            }
        } check: { error in
            guard let cliError = error as? CLIError else {
                return XCTFail("expected CLIError, got \(error)")
            }
            XCTAssertTrue(cliError.isStateUncertain)
        }
        XCTAssertEqual(phases.values, ["awaiting_user"])
    }

    // MARK: - App Launch

    func testAppLaunchDecodesStatus() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"app","status":"already_running","app_id":"com.openai.codex","codex_cli_path":null}
        """)
        let service = makeService(runner: runner)

        let response = try await service.executeAppLaunch()
        XCTAssertEqual(response.status, "already_running")
        XCTAssertEqual(response.appId, "com.openai.codex")
        XCTAssertEqual(runner.invocations(for: "app").first, ["app", "--json"])
    }

    // MARK: - Login Fixtures

    private let loginTwoPhaseJSON = """
    {"schema_version":1,"command":"login","mode":"device_auth","phase":"awaiting_user","verification_url":"https://auth.openai.com/codex/device","user_code":"TEST-1234"}
    {"schema_version":1,"command":"login","mode":"device_auth","phase":"completed","active_account_key":"key-login","account":{"number":1,"account_key":"key-login","email":"login-json@example.com","alias":null,"account_name":null,"plan":"plus","auth_mode":"chatgpt","active":true,"created_at":1730000000,"last_used_at":1730001000,"usage":null}}
    """
}

// MARK: - Async Assertion Helper

/// 对 async throwing 闭包断言抛错并校验错误值。
func assertThrowsAsyncError<T>(
    _ execute: () async throws -> T,
    check: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await execute()
        XCTFail("expected error, got success", file: file, line: line)
    } catch {
        check(error)
    }
}

// MARK: - P4 Extensions

extension CLIProcessServiceTests {
    func testSwitchPreviousBuildsArgumentsAndDecodes() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: switchJSON)
        let service = makeService(runner: runner)

        let switched = try await service.executeSwitchPrevious()
        XCTAssertEqual(switched.accountKey, "key-b")
        XCTAssertEqual(runner.invocations(for: "switch").first, ["switch", "--previous", "--json"])
    }

    func testCleanDecodesCounts() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"clean","target":"accounts","auth_backups_removed":1,"registry_backups_removed":2,"stale_snapshot_files_removed":3,"platform":null,"files_removed":null}
        """)
        let service = makeService(runner: runner)

        let response = try await service.executeClean()
        XCTAssertEqual(response.authBackupsRemoved, 1)
        XCTAssertEqual(response.registryBackupsRemoved, 2)
        XCTAssertEqual(response.staleSnapshotFilesRemoved, 3)
        XCTAssertEqual(runner.invocations(for: "clean").first, ["clean", "--json"])
    }

    func testConfigGetAndSetBuildArguments() async throws {
        let runner = FakeCLIProcessRunner()
        runner.enqueue(stdout: probeJSON)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"config","section":"live","interval_seconds":60}
        """)
        runner.enqueue(stdout: """
        {"schema_version":1,"command":"config","section":"live","interval_seconds":120}
        """)
        let service = makeService(runner: runner)

        let get = try await service.executeConfigGet()
        XCTAssertEqual(get.intervalSeconds, 60)
        XCTAssertEqual(runner.invocations(for: "config").first, ["config", "get", "--json"])

        let set = try await service.executeConfigSetLiveInterval(120)
        XCTAssertEqual(set.intervalSeconds, 120)
        XCTAssertEqual(runner.invocations(for: "config").last, ["config", "live", "--interval", "120", "--json"])
    }
}
