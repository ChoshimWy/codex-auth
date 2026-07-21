import Foundation

// MARK: - Localization

enum L10n {
    static var appTitle:       String { loc("app.title") }
    static var appRefreshAX:   String { loc("app.refresh.ax") }
    static var appSettingsAX:  String { loc("app.settings.ax") }

    static var sectionOtherAccounts: String { loc("section.other_accounts") }
    static var footerLoading:        String { loc("footer.loading") }

    static func footerAccounts(_ count: Int) -> String {
        String(format: loc("footer.accounts"), count)
    }
    static func footerLastSync(_ time: String) -> String {
        String(format: loc("footer.last_sync"), time)
    }
    static func cardUpdated(_ time: String) -> String {
        String(format: loc("card.updated"), time)
    }

    static var cardRemaining: String { loc("card.remaining") }

    static func cardResets(_ count: Int) -> String {
        String(format: loc("card.resets"), count)
    }

    static func usageResets(_ date: String) -> String {
        String(format: loc("usage.resets"), date)
    }

    static var sourceAPI:     String { loc("source.api") }
    static var sourceLocal:   String { loc("source.local") }
    static var sourceCached:  String { loc("source.cached") }
    static var sourceOffline: String { loc("source.offline") }

    static var rowSwitch:      String { loc("row.switch") }
    static var rowCopyEmail:   String { loc("row.copy_email") }
    static var rowViewDetails: String { loc("row.view_details") }
    static var rowRemove:      String { loc("row.remove") }
    static var rowSwitching:   String { loc("row.switching") }

    static var statusLoading:    String { loc("status.loading") }
    static var statusRefreshing: String { loc("status.refreshing") }
    static var statusError:      String { loc("status.error") }
    static var statusDefault:    String { loc("status.default") }
    static var quit:             String { loc("quit") }

    static var settingsGeneral:         String { loc("settings.general") }
    static var settingsAbout:           String { loc("settings.about") }
    static var settingsLanguage:        String { loc("settings.language") }
    static var settingsConfirmSwitch:   String { loc("settings.confirm_switch") }
    static var settingsRefreshInterval: String { loc("settings.refresh_interval") }
    static var settingsLaunchAtLogin:   String { loc("settings.launch_at_login") }
    static var settingsAboutTitle:      String { loc("settings.about.title") }
    static var settingsAboutSubtitle:   String { loc("settings.about.subtitle") }
    static var settingsVersion:         String { loc("settings.version") }
    static var settingsLangSystem:      String { loc("settings.lang.system") }
    static var settingsLangNote:        String { loc("settings.lang.note") }

    static func settingsLowThreshold(_ pct: Int) -> String {
        String(format: loc("settings.low_threshold"), pct)
    }

    static func planName(_ raw: String) -> String {
        loc("plan.\(raw.lowercased())")
    }

    static var cliNotFound:     String { loc("cli.not_found") }
    static var cliInvalidOutput: String { loc("cli.invalid_output") }

    static func cliExitCode(_ code: Int32) -> String {
        String(format: loc("cli.exit_code"), code)
    }

    // MARK: - Compiled-in Strings

    private static let en: [String: String] = [
        "app.title": "Codex Switcher",
        "app.refresh.ax": "Refresh account usage",
        "app.settings.ax": "Open Settings",
        "section.other_accounts": "Other Accounts",
        "footer.loading": "Loading…",
        "footer.accounts": "%lld accounts",
        "footer.last_sync": "Last sync: %@",
        "card.updated": "Updated %@",
        "card.remaining": "Remaining",
        "card.resets": "%lld reset left",
        "usage.resets": "Resets %@",
        "source.api": "API",
        "source.local": "Local",
        "source.cached": "Cached",
        "source.offline": "Offline",
        "row.switch": "Switch to Account",
        "row.copy_email": "Copy Email",
        "row.view_details": "View Details",
        "row.remove": "Remove Account",
        "row.switching": "Switching…",
        "status.loading": "Loading…",
        "status.refreshing": "Refreshing…",
        "status.error": "Error",
        "status.default": "Codex",
        "quit": "Quit",
        "settings.general": "General",
        "settings.about": "About",
        "settings.language": "Language",
        "settings.low_threshold": "Low capacity threshold: %lld%%",
        "settings.confirm_switch": "Confirm before switching accounts",
        "settings.refresh_interval": "Refresh interval",
        "settings.launch_at_login": "Launch at login",
        "settings.about.title": "Codex Switcher",
        "settings.about.subtitle": "macOS menu-bar companion for codex-auth",
        "settings.version": "Version 0.1.0",
        "settings.lang.system": "System Default",
        "settings.lang.note": "Language changes take effect on next launch.",
        "plan.free": "Free", "plan.plus": "Plus", "plan.pro": "Pro",
        "plan.business": "Business", "plan.enterprise": "Enterprise",
        "plan.edu": "Edu", "plan.unknown": "Unknown",
        "cli.not_found": "codex-auth CLI not found",
        "cli.invalid_output": "Invalid CLI output",
        "cli.exit_code": "CLI exited with code %lld",
    ]

    private static let zh: [String: String] = [
        "app.title": "Codex Switcher",
        "app.refresh.ax": "刷新账户用量",
        "app.settings.ax": "打开设置",
        "section.other_accounts": "其他账号",
        "footer.loading": "加载中…",
        "footer.accounts": "%lld 个账号",
        "footer.last_sync": "上次同步：%@",
        "card.updated": "%@ 更新",
        "card.remaining": "剩余",
        "card.resets": "剩余 %lld 次重置",
        "usage.resets": "%@ 重置",
        "source.api": "API",
        "source.local": "本地",
        "source.cached": "缓存",
        "source.offline": "离线",
        "row.switch": "切换到此账号",
        "row.copy_email": "复制邮箱",
        "row.view_details": "查看详情",
        "row.remove": "移除账号",
        "row.switching": "切换中…",
        "status.loading": "加载中…",
        "status.refreshing": "刷新中…",
        "status.error": "错误",
        "status.default": "Codex",
        "quit": "退出",
        "settings.general": "通用",
        "settings.about": "关于",
        "settings.language": "语言",
        "settings.low_threshold": "低容量阈值：%lld%%",
        "settings.confirm_switch": "切换账号前确认",
        "settings.refresh_interval": "刷新间隔",
        "settings.launch_at_login": "登录时启动",
        "settings.about.title": "Codex Switcher",
        "settings.about.subtitle": "macOS 菜单栏 codex-auth 助手",
        "settings.version": "版本 0.1.0",
        "settings.lang.system": "跟随系统",
        "settings.lang.note": "语言更改将在下次启动时生效",
        "plan.free": "Free", "plan.plus": "Plus", "plan.pro": "Pro",
        "plan.business": "Business", "plan.enterprise": "Enterprise",
        "plan.edu": "Edu", "plan.unknown": "未知",
        "cli.not_found": "未找到 codex-auth CLI",
        "cli.invalid_output": "CLI 输出无效",
        "cli.exit_code": "CLI 退出码 %lld",
    ]

    private static let table: [String: String] = {
        let stored = UserDefaults.standard.string(forKey: "language") ?? "system"
        switch stored {
        case "en": return en
        case "zh": return zh
        default:   // "system" — detect from OS
            let langs = UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]
                ?? Locale.preferredLanguages
            return langs.first?.lowercased().hasPrefix("zh") == true ? zh : en
        }
    }()

    private static func loc(_ key: String) -> String {
        table[key] ?? key
    }
}
