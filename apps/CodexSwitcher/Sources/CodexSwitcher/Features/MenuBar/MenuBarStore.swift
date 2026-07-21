import Foundation
import Observation

@MainActor
@Observable
final class MenuBarStore {
    var accounts: [CodexAccount] = []
    var isRefreshing = false
    var switchingAccountID: CodexAccount.ID?
    var errorMessage: String?
    var lastSyncTime: Date?

    /// Non-nil when confirm-before-switch dialog should show.
    var pendingSwitchAccount: CodexAccount?

    private var activeAccountKey: String?

    var activeAccount: CodexAccount? {
        if let key = activeAccountKey {
            return accounts.first(where: { $0.id == key })
        }
        return accounts.first(where: \.isActive)
    }

    var inactiveAccounts: [CodexAccount] {
        accounts.filter { $0.id != activeAccount?.id }
    }

    /// Whether the user wants a confirmation dialog before switching.
    private var confirmBeforeSwitch: Bool {
        UserDefaults.standard.bool(forKey: "confirmBeforeSwitch")
    }

    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil
        defer { isRefreshing = false }

        do {
            let response = try await CLIProcessService.shared.executeList()
            accounts = AccountMapper.map(response)
            activeAccountKey = response.activeAccountKey
            lastSyncTime = .now
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Switch

    /// Requests a switch. If confirmation is enabled, sets `pendingSwitchAccount`
    /// so the UI can show a dialog; otherwise switches immediately.
    func requestSwitch(to account: CodexAccount) {
        if confirmBeforeSwitch {
            pendingSwitchAccount = account
        } else {
            Task { await switchAccount(to: account) }
        }
    }

    /// Confirms the pending switch.
    func confirmSwitch() {
        guard let account = pendingSwitchAccount else { return }
        pendingSwitchAccount = nil
        Task { await switchAccount(to: account) }
    }

    /// Cancels the pending switch dialog.
    func cancelSwitch() {
        pendingSwitchAccount = nil
    }

    func switchAccount(to account: CodexAccount) async {
        guard switchingAccountID == nil else { return }
        switchingAccountID = account.id
        defer { switchingAccountID = nil }

        guard let path = await CLIProcessService.shared.resolvePath() else {
            errorMessage = L10n.cliNotFound
            return
        }
        let accountId = account.id

        let result: (success: Bool, message: String?) = await Task.detached {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: path)
            task.arguments = ["switch", accountId, "--json"]

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            task.standardOutput = stdoutPipe
            task.standardError = stderrPipe

            do {
                try task.run()
                task.waitUntilExit()
            } catch {
                return (false, error.localizedDescription)
            }

            let exitOK = task.terminationStatus == 0

            var message: String?
            if !exitOK {
                if let data = try? stderrPipe.fileHandleForReading.readToEnd(),
                   let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !msg.isEmpty {
                    message = msg
                } else if let data = try? stdoutPipe.fileHandleForReading.readToEnd(),
                          let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !raw.isEmpty,
                          let json = try? JSONDecoder().decode([String: String].self, from: raw.data(using: .utf8) ?? Data()),
                          let err = json["error"] {
                    message = err
                }
            }

            return (exitOK, message)
        }.value

        if result.success {
            await refresh()
        } else {
            errorMessage = result.message ?? "Switch failed"
        }
    }
}
