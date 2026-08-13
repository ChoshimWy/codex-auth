import SwiftUI
import Network
import UserNotifications

@main
struct CodexSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView(store: appDelegate.store)
                .frame(width: 480, height: 360)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    let store = MenuBarStore()

    /// 网络状态监视:离线时跳过周期后台刷新(PRD Section 10 网络策略)。
    private let networkMonitor = NWPathMonitor()
    private var networkAvailable = true

    /// 阈值通知观察者与上次已通知账号,防重复通知。
    private var thresholdObserver: NSObjectProtocol?
    private var lastNotifiedAccountID: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(store: store)

        // Auto-refresh on launch — data is ready before user opens popover.
        // 首次 API 刷新若隐私披露未确认,refresh 仅置 pending 状态,由弹窗展示披露。
        Task { await store.refresh() }

        // Capability probe for fail-closed mutation gating (FR-13).
        Task { await store.loadCapabilities() }

        // CLI 安装/更新向导:内置版本与上次安装记录不一致时提示(PRD Section 13)。
        Task { await store.checkCLIInstallWizard() }

        // 网络感知的后台刷新(仅在线时执行)。
        startNetworkAwarePeriodicRefresh()

        // 阈值跨过通知(开关在设置中开启时)。
        observeThresholdCrossing()
    }

    private func startNetworkAwarePeriodicRefresh() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                self?.networkAvailable = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue(label: "codexswitcher.network"))

        Task {
            let key = "refreshInterval"
            while !Task.isCancelled {
                let interval = UserDefaults.standard.integer(forKey: key)
                let seconds = interval > 0 ? interval : 300
                try? await Task.sleep(for: .seconds(seconds))
                guard !store.isRefreshing else { continue }
                // 网络策略:开启"仅在线刷新"且当前离线时跳过本轮。
                let networkOnly = UserDefaults.standard.object(forKey: "refreshOnlyOnNetwork") as? Bool ?? true
                guard networkAvailable || !networkOnly else { continue }
                await store.refresh()
            }
        }
    }

    private func observeThresholdCrossing() {
        thresholdObserver = NotificationCenter.default.addObserver(
            forName: .codexSwitcherThresholdCrossed,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let info = notification.userInfo,
                  let accountName = info["account"] as? String,
                  let remaining = info["remaining"] as? Int else { return }
            let key = "\(accountName)-\(remaining)"
            guard key != self.lastNotifiedAccountID else { return }
            self.lastNotifiedAccountID = key
            self.sendThresholdNotification(accountName: accountName, remaining: remaining)
        }
    }

    private func sendThresholdNotification(accountName: String, remaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = L10n.notificationThresholdTitle
        content.body = L10n.notificationThresholdBody(accountName, remaining)
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
