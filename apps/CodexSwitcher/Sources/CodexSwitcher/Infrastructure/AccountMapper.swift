import Foundation

// MARK: - Account Mapper

/// Maps raw CLI JSON models to display-ready CodexAccount models.
enum AccountMapper {

    static func map(_ response: CLIListResponse) -> [CodexAccount] {
        response.accounts.map(mapAccount)
    }

    static func mapAccount(_ cli: CLIAccount) -> CodexAccount {
        let alias = cli.alias?.trimmingCharacters(in: .whitespaces)
            ?? cli.accountName?.trimmingCharacters(in: .whitespaces)
            ?? cli.email?.components(separatedBy: "@").first
            ?? "Account"

        let email = cli.email ?? "unknown"

        let plan = AccountPlan(rawValue: cli.plan ?? "") ?? .unknown

        let primary = mapUsageWindow(cli.usage?.primary, windowMinutes: cli.usage?.primary?.windowMinutes)
        let secondary = mapUsageWindow(cli.usage?.secondary, windowMinutes: cli.usage?.secondary?.windowMinutes)

        let credits = extractCredits(cli.usage)

        let source = RefreshSource(rawValue: cli.usage?.source ?? "") ?? .none

        return CodexAccount(
            id: cli.accountKey,
            alias: alias,
            email: email,
            plan: plan,
            isActive: cli.active,
            primaryUsage: primary,
            secondaryUsage: secondary,
            credits: credits,
            refreshSource: source,
            lastUpdatedAt: cli.usage?.updatedAt
        )
    }

    private static func mapUsageWindow(_ window: CLIUsageWindow?, windowMinutes: Int?) -> UsageWindow? {
        guard let window, let used = window.usedPercent else { return nil }
        let title = windowTitle(minutes: windowMinutes ?? window.windowMinutes)
        return UsageWindow(
            title: title,
            usedPercent: used,
            resetAt: window.resetsAt
        )
    }

    private static func windowTitle(minutes: Int?) -> String {
        guard let minutes else { return "Usage" }
        switch minutes {
        case 300:   return "5h Window"
        case 10080: return "7d Window"
        case 1440:  return "24h Window"
        default:
            if minutes < 60 { return "\(minutes)m Window" }
            return "\(minutes / 60)h Window"
        }
    }

    private static func extractCredits(_ usage: CLIUsage?) -> Int? {
        guard let usage else { return nil }
        // Prefer credits.balance if has_credits and numeric
        if usage.credits?.hasCredits == true,
           let balanceStr = usage.credits?.balance,
           let balance = Int(balanceStr.filter({ $0.isNumber || $0 == "-" })),
           balance > 0 {
            return balance
        }
        // Fall back to reset_credits (include 0 so user sees "0 resets")
        return usage.resetCredits
    }
}

// MARK: - Dependency Injection Helpers

/// Parsed CLI result, preserving the raw active_account_key for store reconciliation.
struct ParsedCLIResult {
    let accounts: [CodexAccount]
    let activeAccountKey: String?
}
