import Foundation

// MARK: - CLI Process Service

/// `codex-auth` JSON 契约的统一执行层。
///
/// 所有 CLI 交互(读与变更)都经由此 actor 串行执行:actor 方法天然互斥,
/// 满足契约「prevent overlapping commands」要求;UI 侧用 `Task.detached`
/// 调用避免阻塞主线程。每个响应在返回前校验 `schema_version == 1`,
/// 退出码 1 的 stdout 解析为结构化错误文档(契约见 docs/json-api.md)。
actor CLIProcessService {
    static let shared = CLIProcessService()

    // MARK: - Seams

    /// CLI 路径解析注入点(测试可替换;默认含 Settings 固定路径 → 内置 → PATH → 已知路径)。
    private let pathProvider: @Sendable () -> String?

    /// 子进程执行注入点(测试可替换为脚本化 fake runner)。
    private let runner: any CLIProcessRunner

    init(
        pathProvider: @escaping @Sendable () -> String? = { CLIProcessService.resolveDefaultPath() },
        runner: any CLIProcessRunner = SystemCLIProcessRunner()
    ) {
        self.pathProvider = pathProvider
        self.runner = runner
    }

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    // MARK: - Capability Cache

    /// 探测结果按「解析到的 CLI 路径」缓存:路径变化(Settings 改路径、
    /// 新装 CLI 后 PATH 解析变化)时自动重探,避免失败/旧结果粘滞到进程结束。
    private var cachedCapabilities: CLICapabilities?
    private var probedPath: String?
    private var failedPath: String?

    // MARK: - CLI Discovery

    func resolvePath() -> String? {
        pathProvider()
    }

    /// 默认路径解析:Settings 固定路径 → App 内置 → `which` → 已知安装路径。
    static func resolveDefaultPath() -> String? {
        // 0. User-pinned path from Settings (FR-7); invalid pins fall through.
        if let pinned = UserDefaults.standard.string(forKey: "codexAuthPath"),
           !pinned.isEmpty,
           FileManager.default.isExecutableFile(atPath: pinned) {
            return pinned
        }

        // 1. Bundled codex-auth (shipped inside the .app bundle)
        //    Bundle.module crashes in .app context; use Bundle.main paths instead.
        if let bundledPath = Self.findBundledCLI() {
            return bundledPath
        }

        // 2. System PATH lookup
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        which.arguments = ["which", "codex-auth"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice

        if let _ = try? which.run() {
            which.waitUntilExit()
            if which.terminationStatus == 0,
               let data = try? pipe.fileHandleForReading.readToEnd(),
               let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty {
                return path
            }
        }

        // 3. Known install paths
        for known in Self.knownPaths {
            if FileManager.default.isExecutableFile(atPath: known) { return known }
        }
        return nil
    }

    private static let knownPaths = [
        "/opt/homebrew/bin/codex-auth",
        "/usr/local/bin/codex-auth",
    ]

    private static let resourceBundleName = "CodexSwitcher_CodexSwitcher.bundle"
    private static let bundledCLIName = "codex-auth"

    /// Locates the bundled `codex-auth` binary without using `Bundle.module`
    /// (which crashes in a repackaged `.app` bundle because SPM cannot resolve
    /// the resource path at runtime).
    static func findBundledCLI() -> String? {
        let relative = (resourceBundleName as NSString).appendingPathComponent(bundledCLIName)

        // a) Inside .app bundle: Contents/Resources/<bundle>/codex-auth
        if let resourcePath = Bundle.main.resourcePath {
            let path = (resourcePath as NSString).appendingPathComponent(relative)
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }

        // b) SPM dev layout: executable dir / <bundle> / codex-auth
        if let executableURL = Bundle.main.executableURL {
            let path = executableURL
                .deletingLastPathComponent()
                .appendingPathComponent(relative)
                .path
            if FileManager.default.isExecutableFile(atPath: path) { return path }
        }

        return nil
    }

    // MARK: - Unified Runner

    /// 执行一次 CLI 调用并返回原始结果(串行、互斥)。
    func run(arguments: [String]) throws -> CLIRunResult {
        guard let path = pathProvider() else { throw CLIError.notFound }
        return try runner.run(executable: path, arguments: arguments)
    }

    // MARK: - Commands

    /// `list --json`;`skipAPI` 为 true 时追加 `--skip-api`(local-only 刷新)。
    func executeList(skipAPI: Bool = false) throws -> CLIListResponse {
        var arguments = ["list"]
        if skipAPI { arguments.append("--skip-api") }
        arguments.append("--json")

        let result = try run(arguments: arguments)
        try validateExit(result)
        let response: CLIListResponse = try decode(CLIListResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// `switch <account_key> --json`;返回 `switched_to` 账户对象。
    func executeSwitch(accountKey: String) throws -> CLIAccount {
        try ensureCapability("switch")
        let result = try run(arguments: ["switch", accountKey, "--json"])
        try validateExit(result)
        let response: CLISwitchResponse = try decode(CLISwitchResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response.switchedTo
    }

    /// `remove <account_key> --json`;返回 removed 列表与新活跃键。
    func executeRemove(accountKey: String) throws -> CLIRemoveResponse {
        try ensureCapability("remove")
        let result = try run(arguments: ["remove", accountKey, "--json"])
        try validateExit(result)
        let response: CLIRemoveResponse = try decode(CLIRemoveResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// 能力探测(`--version --json`),按 CLI 路径缓存;失败返回 nil 且对
    /// 同一路径不再重试,但路径变化或显式 `resetCapabilities()` 后会重探。
    /// 未知/不可探测的 CLI 一律 fail-closed:变更命令会抛 `missingCapability`。
    func capabilities() -> CLICapabilities? {
        let currentPath = pathProvider()
        if let cached = cachedCapabilities, probedPath == currentPath { return cached }
        guard let currentPath else { return nil }
        guard failedPath != currentPath else { return nil }

        do {
            let result = try run(arguments: ["--version", "--json"])
            guard result.exitCode == 0 else {
                throw CLIError.executionFailed(result.exitCode)
            }
            let document: CLIVersionResponse = try decode(CLIVersionResponse.self, from: result.stdout)
            try validateSchema(document.schemaVersion)
            guard document.jsonApiSchema == 1 else {
                throw CLIError.unsupportedSchema(document.jsonApiSchema)
            }
            let capabilities = CLICapabilities(
                version: document.version,
                supportedCommands: Set(document.supportedCommands)
            )
            cachedCapabilities = capabilities
            probedPath = currentPath
            failedPath = nil
            return capabilities
        } catch {
            cachedCapabilities = nil
            probedPath = nil
            failedPath = currentPath
            return nil
        }
    }

    /// 显式清除能力缓存(Settings 修改 CLI 路径时调用),下次探测重新执行。
    func resetCapabilities() {
        cachedCapabilities = nil
        probedPath = nil
        failedPath = nil
    }

    // MARK: - Account Management Commands

    /// `alias set <account_key> <alias> --json`;返回更新后的账户对象。
    func executeAliasSet(accountKey: String, alias: String) throws -> CLIAccount {
        try ensureCapability("alias")
        let result = try run(arguments: ["alias", "set", accountKey, alias, "--json"])
        try validateExit(result)
        let response: CLIAliasResponse = try decode(CLIAliasResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response.updated
    }

    /// `alias clear <account_key> --json`;返回更新后的账户对象(alias 为 null)。
    func executeAliasClear(accountKey: String) throws -> CLIAccount {
        try ensureCapability("alias")
        let result = try run(arguments: ["alias", "clear", accountKey, "--json"])
        try validateExit(result)
        let response: CLIAliasResponse = try decode(CLIAliasResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response.updated
    }

    /// `import (--cpa|--purge) [<path>] [--alias <alias>] --json`。
    func executeImport(path: String?, alias: String?, mode: ImportMode) throws -> CLIImportResponse {
        try ensureCapability("import")
        var arguments = ["import"]
        switch mode {
        case .standard:
            guard let path else { throw CLIError.invalidOutput }
            arguments.append(path)
        case .cpa:
            arguments.append("--cpa")
            if let path { arguments.append(path) }
        case .purge:
            arguments.append("--purge")
            if let path { arguments.append(path) }
        }
        if mode == .standard, let alias {
            arguments.append("--alias")
            arguments.append(alias)
        }
        arguments.append("--json")

        let result = try run(arguments: arguments)
        try validateExit(result)
        let response: CLIImportResponse = try decode(CLIImportResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// `export [<dir>] [--cpa] --json`。
    func executeExport(destination: String?, format: ExportFormat) throws -> CLIExportResponse {
        try ensureCapability("export")
        var arguments = ["export"]
        if let destination { arguments.append(destination) }
        if format == .cpa { arguments.append("--cpa") }
        arguments.append("--json")

        let result = try run(arguments: arguments)
        try validateExit(result)
        let response: CLIExportResponse = try decode(CLIExportResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// `login --device-auth --json` 流式执行:每个相位文档经 `onPhase` 回调
    /// (后台线程),返回最后的相位文档;流中出现标准错误文档则抛结构化错误。
    /// 登录会话会长时间存活,不走命令序列化(契约中的多文档例外)。
    func executeLoginDeviceAuth(
        isCancelled: @escaping @Sendable () -> Bool,
        onPhase: @escaping @Sendable (CLILoginPhaseDocument) -> Void
    ) async throws -> CLILoginPhaseDocument? {
        try ensureCapability("login")
        guard let path = pathProvider() else { throw CLIError.notFound }
        let runner = self.runner

        let box = LoginPhaseBox()
        return try await Task.detached {
            let exitCode = try runner.runStreaming(
                executable: path,
                arguments: ["login", "--device-auth", "--json"],
                isCancelled: isCancelled
            ) { data in
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                decoder.dateDecodingStrategy = .secondsSince1970
                guard let raw = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    let jsonData = raw.data(using: .utf8) else { return }

                if let document = try? decoder.decode(CLILoginPhaseDocument.self, from: jsonData),
                   document.schemaVersion == 1,
                   document.phase == "awaiting_user" || document.phase == "completed" || document.phase == "failed" {
                    box.setPhase(document)
                    onPhase(document)
                } else if let errorDocument = try? decoder.decode(CLIErrorDocument.self, from: jsonData),
                          errorDocument.schemaVersion == 1 {
                    box.setError(.structured(
                        code: errorDocument.error.code,
                        message: errorDocument.error.message
                    ))
                }
            }

            if let structuredError = box.error { throw structuredError }
            if exitCode != 0 {
                // 异常退出且未到达终态相位(completed/failed)时抛错,
                // 避免 UI 停留在 awaiting_user 状态。
                let terminal = box.last.map { $0.phase == "completed" || $0.phase == "failed" } ?? false
                if !terminal {
                    throw CLIError.executionFailed(exitCode)
                }
            }
            return box.last
        }.value
    }

    /// `app --json`;返回 launched / already_running 状态。
    func executeAppLaunch() throws -> CLIAppResponse {
        try ensureCapability("app")
        let result = try run(arguments: ["app", "--json"])
        try validateExit(result)
        let response: CLIAppResponse = try decode(CLIAppResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// `switch --previous --json`;返回 `switched_to` 账户对象。
    func executeSwitchPrevious() throws -> CLIAccount {
        try ensureCapability("switch")
        let result = try run(arguments: ["switch", "--previous", "--json"])
        try validateExit(result)
        let response: CLISwitchResponse = try decode(CLISwitchResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response.switchedTo
    }

    /// `clean [background] --json`;返回清理计数。
    func executeClean(background: Bool = false) throws -> CLICleanResponse {
        try ensureCapability("clean")
        var arguments = ["clean"]
        if background { arguments.append("background") }
        arguments.append("--json")
        let result = try run(arguments: arguments)
        try validateExit(result)
        let response: CLICleanResponse = try decode(CLICleanResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// `config get --json`;读取当前配置(live 间隔)。
    func executeConfigGet() throws -> CLIConfigResponse {
        try ensureCapability("config")
        let result = try run(arguments: ["config", "get", "--json"])
        try validateExit(result)
        let response: CLIConfigResponse = try decode(CLIConfigResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    /// `config live --interval <seconds> --json`;写入 live TUI 刷新间隔(5–3600)。
    func executeConfigSetLiveInterval(_ interval: Int) throws -> CLIConfigResponse {
        try ensureCapability("config")
        let result = try run(arguments: ["config", "live", "--interval", String(interval), "--json"])
        try validateExit(result)
        let response: CLIConfigResponse = try decode(CLIConfigResponse.self, from: result.stdout)
        try validateSchema(response.schemaVersion)
        return response
    }

    // MARK: - Validation

    private func ensureCapability(_ command: String) throws {
        guard let capabilities = capabilities() else {
            throw CLIError.missingCapability(command: command, version: nil)
        }
        guard capabilities.supports(command) else {
            throw CLIError.missingCapability(command: command, version: capabilities.version)
        }
    }

    /// 退出码 0 才算成功;1/2 时 stdout 优先解析为结构化错误文档(错误文档
    /// 同样校验 schema,避免以未知 schema 的错误文档当作业务错误展示)。
    private func validateExit(_ result: CLIRunResult) throws {
        guard result.exitCode != 0 else { return }
        if let document = try? decode(CLIErrorDocument.self, from: result.stdout) {
            if document.schemaVersion != 1 {
                throw CLIError.unsupportedSchema(document.schemaVersion)
            }
            throw CLIError.structured(code: document.error.code, message: document.error.message)
        }
        throw CLIError.executionFailed(result.exitCode)
    }

    private func validateSchema(_ version: Int) throws {
        guard version == 1 else { throw CLIError.unsupportedSchema(version) }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        guard !data.isEmpty,
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = raw.data(using: .utf8) else {
            throw CLIError.invalidOutput
        }
        do {
            return try decoder.decode(T.self, from: jsonData)
        } catch {
            throw CLIError.invalidOutput
        }
    }
}

// MARK: - Error

enum CLIError: LocalizedError, Sendable, Equatable {
    case notFound
    case executionFailed(Int32)
    case invalidOutput
    case unsupportedSchema(Int)
    /// 变更命令缺少能力:`version` 为已知 CLI 版本,探测失败时为 nil。
    case missingCapability(command: String, version: String?)
    /// 退出码 1 的结构化错误(契约错误文档);code 如 `state_uncertain`。
    case structured(code: String, message: String)

    /// 契约 `state_uncertain`:变更已开始但持久化失败,须先 `list --json` 成功再重试。
    var isStateUncertain: Bool {
        if case .structured(code: "state_uncertain", _) = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .notFound: return L10n.cliNotFound
        case .executionFailed(let code): return L10n.cliExitCode(code)
        case .invalidOutput: return L10n.cliInvalidOutput
        case .unsupportedSchema(let version): return L10n.cliUnsupportedSchema(version)
        case .missingCapability(let command, let version):
            return L10n.cliMissingCapability(command, version)
        case .structured(_, let message):
            if isStateUncertain { return L10n.cliStateUncertain }
            return message
        }
    }
}

// MARK: - Capabilities

/// `--version --json` 探测结果;变更命令据此 fail-closed 门控。
struct CLICapabilities: Sendable, Equatable {
    let version: String
    let supportedCommands: Set<String>

    func supports(_ command: String) -> Bool {
        supportedCommands.contains(command)
    }
}

// MARK: - Command Options

/// import 三种模式(契约 mode 字段)。
enum ImportMode: String, Sendable {
    case standard
    case cpa
    case purge
}

/// export 两种格式(契约 format 字段)。
enum ExportFormat: String, Sendable {
    case standard
    case cpa
}

// MARK: - Process Runner Seam

/// 原始子进程执行结果。
struct CLIRunResult: Sendable {
    let exitCode: Int32
    let stdout: Data
    let stderr: Data
}

/// 子进程执行协议;`SystemCLIProcessRunner` 为生产实现,测试用脚本化 fake。
protocol CLIProcessRunner: Sendable {
    func run(executable: String, arguments: [String]) throws -> CLIRunResult

    /// 流式执行:每读到一个完整行回调一次,返回退出码。
    /// `isCancelled` 返回 true 时终止子进程(login 取消)。
    func runStreaming(
        executable: String,
        arguments: [String],
        isCancelled: @escaping @Sendable () -> Bool,
        onLine: @escaping @Sendable (Data) -> Void
    ) throws -> Int32
}

extension CLIProcessRunner {
    /// 默认实现:一次性执行后把 stdout 整体作为一行回调(单文档场景)。
    func runStreaming(
        executable: String,
        arguments: [String],
        isCancelled: @escaping @Sendable () -> Bool,
        onLine: @escaping @Sendable (Data) -> Void
    ) throws -> Int32 {
        let result = try run(executable: executable, arguments: arguments)
        if !result.stdout.isEmpty { onLine(result.stdout) }
        return result.exitCode
    }
}

/// 生产实现:stdout/stderr 双管道 + readabilityHandler 收集,防管道死锁。
struct SystemCLIProcessRunner: CLIProcessRunner {
    func run(executable: String, arguments: [String]) throws -> CLIRunResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutCollector = OutputCollector()
        let stderrCollector = OutputCollector()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [stdoutCollector] handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { stdoutCollector.append(chunk) }
        }
        stderrPipe.fileHandleForReading.readabilityHandler = { [stderrCollector] handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { stderrCollector.append(chunk) }
        }

        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        try task.run()
        task.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        stderrPipe.fileHandleForReading.readabilityHandler = nil

        return CLIRunResult(
            exitCode: task.terminationStatus,
            stdout: stdoutCollector.data,
            stderr: stderrCollector.data
        )
    }

    /// 流式执行:stdout 按行回调(login 双相位文档场景),`isCancelled` 终止子进程。
    func runStreaming(
        executable: String,
        arguments: [String],
        isCancelled: @escaping @Sendable () -> Bool,
        onLine: @escaping @Sendable (Data) -> Void
    ) throws -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let stdoutPipe = Pipe()
        let lineBuffer = LineSplitter()
        stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                for line in lineBuffer.append(chunk) {
                    onLine(line)
                }
            }
        }
        task.standardOutput = stdoutPipe
        task.standardError = FileHandle.nullDevice

        try task.run()
        while task.isRunning {
            if isCancelled() {
                task.terminate()
                // SIGTERM 限时等待,超时 SIGKILL 兜底(子进程可能不响应终止信号)。
                var grace = 40  // 40 × 50ms ≈ 2s
                while task.isRunning && grace > 0 {
                    usleep(50_000)
                    grace -= 1
                }
                if task.isRunning {
                    kill(task.processIdentifier, SIGKILL)
                }
                break
            }
            usleep(50_000)
        }
        task.waitUntilExit()
        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        if let remainder = lineBuffer.drain() {
            onLine(remainder)
        }
        return task.terminationStatus
    }
}

/// 登录流的线程安全结果盒:流式回调线程写入,detached 任务读取。
private final class LoginPhaseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _last: CLILoginPhaseDocument?
    private var _error: CLIError?

    func setPhase(_ document: CLILoginPhaseDocument) {
        lock.lock()
        _last = document
        lock.unlock()
    }

    func setError(_ error: CLIError) {
        lock.lock()
        _error = error
        lock.unlock()
    }

    var last: CLILoginPhaseDocument? {
        lock.lock()
        defer { lock.unlock() }
        return _last
    }

    var error: CLIError? {
        lock.lock()
        defer { lock.unlock() }
        return _error
    }
}

/// 线程安全的流式行分割器:readabilityHandler 回调线程上追加数据,
/// 按 `\n` 切分出完整行,EOF 时返回残留半行。
final class LineSplitter: @unchecked Sendable {
    private let lock = NSLock()
    private var buffer = Data()

    func append(_ chunk: Data) -> [Data] {
        lock.lock()
        defer { lock.unlock() }
        buffer.append(chunk)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer.subdata(in: buffer.startIndex..<newline)
            buffer.removeSubrange(buffer.startIndex...newline)
            if !line.isEmpty { lines.append(line) }
        }
        return lines
    }

    func drain() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard !buffer.isEmpty else { return nil }
        let rest = buffer
        buffer.removeAll(keepingCapacity: false)
        return rest
    }
}

/// Thread-safe `Data` accumulator for `FileHandle.readabilityHandler`.
private final class OutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _data = Data()

    func append(_ chunk: Data) {
        lock.lock()
        _data.append(chunk)
        lock.unlock()
    }

    var data: Data {
        lock.lock()
        defer { lock.unlock() }
        return _data
    }
}
