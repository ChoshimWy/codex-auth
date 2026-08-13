import Foundation

enum AccountPlan: String, Codable, Sendable {
    case free
    case plus
    case pro
    case business
    case enterprise
    case edu
    case unknown
}

enum RefreshSource: String, Codable, Sendable {
    case api
    case local
    case cache
    case none
}

struct UsageWindow: Codable, Equatable, Sendable {
    let title: String
    let usedPercent: Double
    let resetAt: Date?

    var remainingPercent: Double {
        max(0, 100 - usedPercent)
    }
}

struct CodexAccount: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let alias: String
    let email: String
    let plan: AccountPlan
    /// 可变:switch 成功后先就地更新活跃标记,再 list 收敛(FR-4)。
    var isActive: Bool
    let primaryUsage: UsageWindow?
    let secondaryUsage: UsageWindow?
    let credits: Int?
    let refreshSource: RefreshSource
    let lastUpdatedAt: Date?
}
