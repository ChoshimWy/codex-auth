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

    // MARK: - CLI Discovery

    func resolvePath() -> String? {
        // 1. Bundled codex-auth (shipped with the app)
        if let bundled = Bundle.module.url(forResource: "codex-auth", withExtension: ""),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled.path
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

    // MARK: - Execute List

    func executeList() throws -> CLIListResponse {
        guard let path = resolvePath() else {
            throw CLIError.notFound
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = ["list", "--json"]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        try task.run()
        task.waitUntilExit()

        // Drain stderr
        _ = try? stderrPipe.fileHandleForReading.readToEnd()

        guard task.terminationStatus == 0,
              let data = try? stdoutPipe.fileHandleForReading.readToEnd(),
              let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
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
