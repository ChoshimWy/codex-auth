import Foundation

// MARK: - CLI Process Service

actor CLIProcessService {
    static let shared = CLIProcessService()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        d.dateDecodingStrategy = .secondsSince1970
        return d
    }()

    private static let knownPaths = [
        "/opt/homebrew/bin/codex-auth",
        "/usr/local/bin/codex-auth",
    ]

    private static let resourceBundleName = "CodexSwitcher_CodexSwitcher.bundle"
    private static let bundledCLIName = "codex-auth"

    // MARK: - CLI Discovery

    func resolvePath() -> String? {
        // 1. Bundled codex-auth (shipped inside the .app bundle)
        //    Bundle.module crashes in .app context; use Bundle.main paths instead.
        if let bundledPath = findBundledCLI() {
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

    /// Locates the bundled `codex-auth` binary without using `Bundle.module`
    /// (which crashes in a repackaged `.app` bundle because SPM cannot resolve
    /// the resource path at runtime).
    private func findBundledCLI() -> String? {
        let relative = (Self.resourceBundleName as NSString).appendingPathComponent(Self.bundledCLIName)

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

    // MARK: - Execute List

    func executeList() throws -> CLIListResponse {
        guard let path = resolvePath() else {
            throw CLIError.notFound
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["list", "--json"]

        let stdoutPipe = Pipe()
        let collector = OutputCollector()

        stdoutPipe.fileHandleForReading.readabilityHandler = { [collector] handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { collector.append(chunk) }
        }

        task.standardOutput = stdoutPipe
        task.standardError = FileHandle.nullDevice

        try task.run()
        task.waitUntilExit()

        stdoutPipe.fileHandleForReading.readabilityHandler = nil
        let data = collector.data

        guard task.terminationStatus == 0,
              !data.isEmpty,
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
            throw CLIError.executionFailed(task.terminationStatus)
        }

        guard let jsonData = raw.data(using: .utf8) else {
            throw CLIError.invalidOutput
        }

        return try decoder.decode(CLIListResponse.self, from: jsonData)
    }
}

enum CLIError: LocalizedError {
    case notFound
    case executionFailed(Int32)
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .notFound: return L10n.cliNotFound
        case .executionFailed(let code): return L10n.cliExitCode(code)
        case .invalidOutput: return L10n.cliInvalidOutput
        }
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
