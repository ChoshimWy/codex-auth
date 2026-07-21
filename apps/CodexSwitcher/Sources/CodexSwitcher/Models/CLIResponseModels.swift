import Foundation

// MARK: - Top-level List Response

struct CLIListResponse: Codable {
    let schemaVersion: Int
    let command: String
    let activeAccountKey: String?
    let accounts: [CLIAccount]
}

// MARK: - Account (raw JSON shape)

struct CLIAccount: Codable {
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

// MARK: - Usage

struct CLIUsage: Codable {
    let source: String?
    let updatedAt: Date?
    let primary: CLIUsageWindow?
    let secondary: CLIUsageWindow?
    let credits: CLICredits?
    let resetCredits: Int?
    let refresh: CLIRefresh?
}

// MARK: - Usage Window

struct CLIUsageWindow: Codable {
    let usedPercent: Double?
    let windowMinutes: Int?
    let resetsAt: Date?
}

// MARK: - Credits

struct CLICredits: Codable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?  // String in real output ("0")
}

// MARK: - Refresh Info

struct CLIRefresh: Codable {
    let requested: Bool?
    let method: String?
    let status: String?
    let httpStatus: Int?
    let errorCode: String?
}
