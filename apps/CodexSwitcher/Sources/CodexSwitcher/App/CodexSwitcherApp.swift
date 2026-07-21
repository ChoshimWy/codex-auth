import SwiftUI

@main
struct CodexSwitcherApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .frame(width: 460, height: 320)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private let store = MenuBarStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController(store: store)

        // Auto-refresh on launch — data is ready before user opens popover
        Task { await store.refresh() }

        // Periodic background refresh every 5 minutes
        startPeriodicRefresh()
    }

    private func startPeriodicRefresh() {
        Task {
            let key = "refreshInterval"
            while !Task.isCancelled {
                let interval = UserDefaults.standard.integer(forKey: key)
                let seconds = interval > 0 ? interval : 300
                try? await Task.sleep(for: .seconds(seconds))
                guard !store.isRefreshing else { continue }
                await store.refresh()
            }
        }
    }
}
