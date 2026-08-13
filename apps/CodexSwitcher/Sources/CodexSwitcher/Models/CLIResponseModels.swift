import Foundation

// MARK: - Top-level List Response

struct CLIListResponse: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let activeAccountKey: String?
    let accounts: [CLIAccount]
}

// MARK: - Account (raw JSON shape)

struct CLIAccount: Codable, Sendable {
    let number: Int
    let accountKey: String
    let email: String?
    let alias: String?
    let accountName: String?
    let plan: String?
    let authMode: String?
    let active: Bool
    let createdAt: Date?
    let lastUsedAt: Date?
    let usage: CLIUsage?
}

// MARK: - Switch Response

struct CLISwitchResponse: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let switchedTo: CLIAccount
}

// MARK: - Remove Response

struct CLIRemoveResponse: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let removed: [CLIAccount]
    let newActiveAccountKey: String?
}

// MARK: - Version / Capability Probe Response

struct CLIVersionResponse: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let version: String
    let jsonApiSchema: Int
    let supportedCommands: [String]
}

// MARK: - Alias Response

struct CLIAliasResponse: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let operation: String
    let updated: CLIAccount
}

// MARK: - Import Response

struct CLIImportResponse: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let mode: String
    let source: String?
    let results: [CLIImportResultRow]
    let importedCount: Int
    let updatedCount: Int
    let skippedCount: Int
    let activeAccountKey: String?
    let registryRebuilt: Bool?
}

struct CLIImportResultRow: Codable, Sendable, Equatable {
    let path: String
    let status: String
    let email: String?
    let reason: String?
}

// MARK: - Export Response

struct CLIExportResponse: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let command: String
    let format: String
    let destination: String
    let exportedCount: Int
    let skippedCount: Int
}

// MARK: - Login Phase Document

/// `login --device-auth --json` 的每相位文档(awaiting_user / completed / failed);
/// 三个相位共用同一形状,未出现的字段为 null。
struct CLILoginPhaseDocument: Codable, Sendable {
    let schemaVersion: Int
    let command: String
    let mode: String
    let phase: String
    let verificationUrl: String?
    let userCode: String?
    let message: String?
    let activeAccountKey: String?
    let account: CLIAccount?
}

// MARK: - App Launch Response

struct CLIAppResponse: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let command: String
    let status: String
    let appId: String?
    let codexCliPath: String?
}

// MARK: - Clean Response

struct CLICleanResponse: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let command: String
    let target: String
    let authBackupsRemoved: Int?
    let registryBackupsRemoved: Int?
    let staleSnapshotFilesRemoved: Int?
    let platform: String?
    let filesRemoved: Int?
}

// MARK: - Config Response

struct CLIConfigResponse: Codable, Sendable, Equatable {
    let schemaVersion: Int
    let command: String
    let section: String
    let intervalSeconds: Int
}

// MARK: - Error Document

/// 退出码 1 时 stdout 携带的结构化错误文档(契约见 docs/json-api.md)。
struct CLIErrorDocument: Codable, Sendable {
    let schemaVersion: Int
    let error: CLIErrorBody

    struct CLIErrorBody: Codable, Sendable {
        let code: String
        let message: String
    }
}

// MARK: - Usage

struct CLIUsage: Codable, Sendable {
    let source: String?
    let updatedAt: Date?
    let primary: CLIUsageWindow?
    let secondary: CLIUsageWindow?
    let credits: CLICredits?
    let resetCredits: Int?
    let refresh: CLIRefresh?
}

// MARK: - Usage Window

struct CLIUsageWindow: Codable, Sendable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: Date?
}

// MARK: - Credits

struct CLICredits: Codable, Sendable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?  // String in real output ("0")
}

// MARK: - Refresh Info

struct CLIRefresh: Codable, Sendable {
    let requested: Bool?
    let method: String?
    let status: String?
    let httpStatus: Int?
    let errorCode: String?
}
