import Foundation

// MARK: - CLI Install / Update (PRD Section 13)

/// 内置 CLI 与本地已装 CLI 的版本/路径信息。
struct CLIInstallInfo: Sendable, Equatable {
    let bundledVersion: String?
    let bundledPath: String?
    let installedVersion: String?
    let installedPath: String?
    let targetDirectory: String?
}

enum CLIInstallError: LocalizedError, Sendable {
    case bundledMissing
    case installFailed(String)

    var errorDescription: String? {
        switch self {
        case .bundledMissing: return L10n.cliInstallBundledMissing
        case .installFailed(let message): return message
        }
    }
}

/// 把 App 内置的 `codex-auth` 安装/覆盖到系统 PATH 目录。
///
/// 策略(用户已确认):总是覆盖为内置版本;新版本本地 CLI 被覆盖前由 UI 展示确认。
/// 目录智能检测:`/opt/homebrew/bin` → `/usr/local/bin` → `~/.local/bin`;
/// 目标目录不可写时经 osascript 请求一次性管理员授权。
actor CLIInstaller {
    static let shared = CLIInstaller()

    private let runner: any CLIProcessRunner
    /// 内置二进制路径解析 seam(测试注入;默认走 App bundle 查找)。
    private let bundledPathProvider: @Sendable () -> String?
    /// 已装副本路径解析 seam(测试注入;默认 `which codex-auth`)。
    private let installedPathResolver: @Sendable () -> String?

    init(
        runner: any CLIProcessRunner = SystemCLIProcessRunner(),
        bundledPathProvider: @escaping @Sendable () -> String? = { CLIProcessService.findBundledCLI() },
        installedPathResolver: @escaping @Sendable () -> String? = { CLIInstaller.resolveWhichPath() }
    ) {
        self.runner = runner
        self.bundledPathProvider = bundledPathProvider
        self.installedPathResolver = installedPathResolver
    }

    /// 候选安装目录(按默认 PATH 优先级)。
    static let candidateDirectories: [String] = {
        var dirs = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
        ]
        dirs.append(NSString(string: "~/.local/bin").expandingTildeInPath)
        return dirs
    }()

    /// 检测内置版本、已装版本与默认安装目标。
    func detect() async -> CLIInstallInfo {
        let bundledPath = bundledPathProvider()
        let bundledVersion = bundledPath.flatMap { Self.versionFor(path: $0, runner: runner) }
        let installed = Self.detectInstalled(
            runner: runner,
            resolvedPath: installedPathResolver()
        )
        return CLIInstallInfo(
            bundledVersion: bundledVersion,
            bundledPath: bundledPath,
            installedVersion: installed?.version,
            installedPath: installed?.path,
            targetDirectory: Self.defaultTargetDirectory()
        )
    }

    /// 已装副本:优先解析已装路径(默认 `which codex-auth` 的真实路径,
    /// 含 npm 符号链接),再查候选目录。
    nonisolated static func detectInstalled(
        runner: any CLIProcessRunner,
        resolvedPath: String?
    ) -> (path: String, version: String?)? {
        if let resolvedPath, let version = versionFor(path: resolvedPath, runner: runner) {
            return (resolvedPath, version)
        }
        for directory in candidateDirectories {
            let path = (directory as NSString).appendingPathComponent("codex-auth")
            if FileManager.default.isExecutableFile(atPath: path),
               let version = versionFor(path: path, runner: runner) {
                return (path, version)
            }
        }
        return nil
    }

    /// 默认安装目标:第一个存在且可写的 PATH 目录;否则 `~/.local/bin`。
    nonisolated static func defaultTargetDirectory() -> String? {
        for directory in candidateDirectories {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory),
                  isDirectory.boolValue else { continue }
            if FileManager.default.isWritableFile(atPath: directory) { return directory }
            // 不可写但存在的 Homebrew 目录也作为目标(安装时走管理员授权)。
            return directory
        }
        return candidateDirectories.last
    }

    /// 探测某路径二进制的能力版本(`--version --json`);失败返回 nil。
    nonisolated static func versionFor(path: String, runner: any CLIProcessRunner) -> String? {
        guard let result = try? runner.run(executable: path, arguments: ["--version", "--json"]),
              result.exitCode == 0,
              let raw = String(data: result.stdout, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let jsonData = raw.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let document = try? decoder.decode(CLIVersionResponse.self, from: jsonData),
              document.schemaVersion == 1 else { return nil }
        return document.version
    }

    /// 安装(总是覆盖):目标目录存在且可写走原子替换;用户主目录下的缺失目录
    /// 直接创建(无需提权);否则管理员授权安装。安装后对产物跑 `--version --json`
    /// 验证(PRD 13.3),验证失败抛错。
    func install(targetDirectory: String?) async throws {
        guard let bundled = bundledPathProvider() else {
            throw CLIInstallError.bundledMissing
        }
        let directory = targetDirectory ?? Self.defaultTargetDirectory() ?? Self.candidateDirectories.last!
        let dest = (directory as NSString).appendingPathComponent("codex-auth")

        var isDirectory: ObjCBool = false
        let directoryExists = FileManager.default.fileExists(atPath: directory, isDirectory: &isDirectory)
            && isDirectory.boolValue
        if directoryExists && FileManager.default.isWritableFile(atPath: directory) {
            try Self.atomicReplace(source: bundled, dest: dest)
        } else if !directoryExists && Self.isUnderUserHome(directory) {
            // 用户主目录下的缺失目录无需提权(避免 root 归属的 ~/.local/bin)。
            try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
            try Self.atomicReplace(source: bundled, dest: dest)
        } else {
            try Self.privilegedInstall(bundled: bundled, directory: directory)
        }

        guard Self.versionFor(path: dest, runner: runner) != nil else {
            throw CLIInstallError.installFailed(L10n.cliInstallVerifyFailed)
        }
    }

    /// 目录是否位于当前用户主目录之下。
    nonisolated static func isUnderUserHome(_ directory: String) -> Bool {
        let home = NSString(string: "~").expandingTildeInPath
        return directory == home || directory.hasPrefix(home + "/")
    }

    /// 语义化版本比较(段内数字;同基础版本时预发布视为更旧)。
    /// 返回 true 表示 `a` 比 `b` 新。
    nonisolated static func isVersion(_ a: String, newerThan b: String) -> Bool {
        let aBase = a.split(separator: "-", maxSplits: 1).first.map(String.init) ?? a
        let bBase = b.split(separator: "-", maxSplits: 1).first.map(String.init) ?? b
        let aParts = aBase.split(separator: ".").compactMap { Int($0) }
        let bParts = bBase.split(separator: ".").compactMap { Int($0) }
        let count = max(aParts.count, bParts.count)
        for index in 0..<count {
            let aValue = index < aParts.count ? aParts[index] : 0
            let bValue = index < bParts.count ? bParts[index] : 0
            if aValue != bValue { return aValue > bValue }
        }
        // 基础版本相同:预发布(a 含 `-`)视为更旧。
        let aIsPrerelease = a.contains("-")
        let bIsPrerelease = b.contains("-")
        if aIsPrerelease != bIsPrerelease { return !aIsPrerelease }
        return false
    }

    /// 同目录临时文件 + 原子替换,保留来源文件的代码签名;失败路径清理临时文件。
    nonisolated static func atomicReplace(source: String, dest: String) throws {
        let directory = (dest as NSString).deletingLastPathComponent
        let temp = (directory as NSString).appendingPathComponent(".codex-auth.install.tmp")
        let fm = FileManager.default
        try? fm.removeItem(atPath: temp)
        defer { try? fm.removeItem(atPath: temp) }
        try fm.copyItem(atPath: source, toPath: temp)
        _ = try fm.replaceItemAt(URL(fileURLWithPath: dest), withItemAt: URL(fileURLWithPath: temp))
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest)
    }

    /// 管理员授权安装(mkdir + cp + chmod),经 osascript 弹出一次性授权。
    nonisolated static func privilegedInstall(bundled: String, directory: String) throws {
        let escapedDir = directory.replacingOccurrences(of: "'", with: "'\\''")
        let escapedSource = bundled.replacingOccurrences(of: "'", with: "'\\''")
        let script = """
        do shell script "mkdir -p '\(escapedDir)' && cp '\(escapedSource)' '\(escapedDir)/codex-auth' && chmod +x '\(escapedDir)/codex-auth'" with administrator privileges
        """
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try task.run()
        task.waitUntilExit()
        guard task.terminationStatus == 0 else {
            let detail = (try? pipe.fileHandleForReading.readToEnd())
                .flatMap { String(data: $0, encoding: .utf8) }?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw CLIInstallError.installFailed(
                detail.isEmpty ? L10n.cliInstallPrivilegedFailed : detail
            )
        }
    }

    /// 解析 `which codex-auth` 的真实路径(解析符号链接,npm 全局安装识别用)。
    nonisolated static func resolveWhichPath() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "codex-auth"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        guard (try? task.run()) != nil else { return nil }
        task.waitUntilExit()
        guard task.terminationStatus == 0,
              let data = try? pipe.fileHandleForReading.readToEnd(),
              let path = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else { return nil }
        return (try? FileManager.default.destinationOfSymbolicLink(atPath: path)).flatMap {
            $0.hasPrefix("/") ? $0 : ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent($0)
        } ?? path
    }
}
