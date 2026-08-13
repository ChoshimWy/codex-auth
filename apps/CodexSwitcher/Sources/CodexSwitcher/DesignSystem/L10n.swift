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
    static var rowRemoving:    String { loc("row.removing") }
    static var rowEditAlias:   String { loc("row.edit_alias") }

    static var headerRefreshAPI:   String { loc("header.refresh_api") }
    static var headerRefreshLocal: String { loc("header.refresh_local") }
    static var headerAddImport:    String { loc("header.add_import") }
    static var headerAddExport:    String { loc("header.add_export") }
    static var headerAddAX:        String { loc("header.add.ax") }

    static var aliasSetTitle:     String { loc("alias.set_title") }
    static var aliasRenameTitle:  String { loc("alias.rename_title") }
    static var aliasPlaceholder:  String { loc("alias.placeholder") }
    static var aliasSaveAction:   String { loc("alias.save_action") }
    static var aliasClearAction:  String { loc("alias.clear_action") }
    static var aliasOptionalLabel: String { loc("alias.optional_label") }
    static var aliasInvalidEmpty:  String { loc("alias.invalid_empty") }
    static var aliasInvalidDigits: String { loc("alias.invalid_digits") }
    static var aliasInvalidControl: String { loc("alias.invalid_control") }

    static var importTitle:          String { loc("import.title") }
    static var importModeLabel:      String { loc("import.mode_label") }
    static var importModeStandard:   String { loc("import.mode_standard") }
    static var importModeCpa:        String { loc("import.mode_cpa") }
    static var importNoPath:         String { loc("import.no_path") }
    static var importChooseAction:   String { loc("import.choose_action") }
    static var importAdvancedLabel:  String { loc("import.advanced_label") }
    static var importPurgeAction:    String { loc("import.purge_action") }
    static var importPurgeWarning:   String { loc("import.purge_warning") }
    static var importRunAction:      String { loc("import.run_action") }
    static func importSummary(_ imported: Int, _ updated: Int, _ skipped: Int) -> String {
        String(format: loc("import.summary"), imported, updated, skipped)
    }
    static func importStatus(_ status: String) -> String {
        loc("import.status.\(status)")
    }

    static var exportTitle:         String { loc("export.title") }
    static var exportFormatLabel:   String { loc("export.format_label") }
    static var exportFormatStandard: String { loc("export.format_standard") }
    static var exportFormatCpa:     String { loc("export.format_cpa") }
    static var exportNoPath:        String { loc("export.no_path") }
    static var exportChooseAction:  String { loc("export.choose_action") }
    static var exportRunAction:     String { loc("export.run_action") }
    static var exportRevealAction:  String { loc("export.reveal_action") }
    static var exportConsentTitle:  String { loc("export.consent_title") }
    static var exportConsentMessage: String { loc("export.consent_message") }
    static var exportConsentConfirm: String { loc("export.consent_confirm") }
    static func exportSummary(_ exported: Int, _ skipped: Int) -> String {
        String(format: loc("export.summary"), exported, skipped)
    }

    static var emptyTitle:        String { loc("empty.title") }
    static var emptyMessage:      String { loc("empty.message") }
    static var emptyImportAction: String { loc("empty.import_action") }
    static var emptyLoginAction:  String { loc("empty.login_action") }

    static var loginTitle:            String { loc("login.title") }
    static var loginWaiting:          String { loc("login.waiting") }
    static var loginStepOpenLink:     String { loc("login.step_open_link") }
    static var loginStepEnterCode:    String { loc("login.step_enter_code") }
    static var loginCopyCode:         String { loc("login.copy_code") }
    static var loginOpenBrowser:      String { loc("login.open_browser") }
    static var loginCompleted:        String { loc("login.completed") }
    static var loginRetry:            String { loc("login.retry") }
    static var loginTerminalFallback: String { loc("login.terminal_fallback") }
    static var loginFailedGeneric:    String { loc("login.failed_generic") }

    static var appLaunchLaunched:       String { loc("app.launch.launched") }
    static var appLaunchAlreadyRunning: String { loc("app.launch.already_running") }
    static var headerLaunchApp:         String { loc("header.launch_app") }
    static var headerAddLogin:          String { loc("header.add_login") }
    static var headerSwitchPrevious:    String { loc("header.switch_previous") }

    static var settingsNotifyThreshold: String { loc("settings.notify_threshold") }
    static var settingsNetworkOnly:     String { loc("settings.network_only") }

    static var maintenanceTitle:            String { loc("maintenance.title") }
    static var maintenanceCleanAction:      String { loc("maintenance.clean_action") }
    static var maintenanceCleanDescription: String { loc("maintenance.clean_description") }
    static var maintenanceLiveInterval:     String { loc("maintenance.live_interval") }
    static func maintenanceCleanSummary(_ auth: Int, _ registry: Int, _ stale: Int) -> String {
        String(format: loc("maintenance.clean_summary"), auth, registry, stale)
    }

    static var notificationThresholdTitle: String { loc("notification.threshold_title") }
    static func notificationThresholdBody(_ account: String, _ remaining: Int) -> String {
        String(format: loc("notification.threshold_body"), account, remaining)
    }

    static var cliInstallTitle:             String { loc("cli.install.title") }
    static var cliInstallAction:            String { loc("cli.install.action") }
    static var cliInstallNote:              String { loc("cli.install.note") }
    static var cliInstallNotInstalled:      String { loc("cli.install.not_installed") }
    static var cliInstallSuccess:           String { loc("cli.install.success") }
    static var cliInstallBundledMissing:    String { loc("cli.install.bundled_missing") }
    static var cliInstallPrivilegedFailed:  String { loc("cli.install.privileged_failed") }
    static var cliInstallPathHint:          String { loc("cli.install.path_hint") }
    static var cliInstallWizardTitle:       String { loc("cli.install.wizard_title") }
    static var cliInstallWizardMessage:     String { loc("cli.install.wizard_message") }
    static var cliInstallWizardInstall:     String { loc("cli.install.wizard_install") }
    static var cliInstallWizardSkip:        String { loc("cli.install.wizard_skip") }
    static var cliInstallVerifyFailed:      String { loc("cli.install.verify_failed") }
    static var cliInstallDowngradeTitle:    String { loc("cli.install.downgrade_title") }
    static var cliInstallDowngradeConfirm:  String { loc("cli.install.downgrade_confirm") }
    static func cliInstallWizardMessageVersions(_ bundled: String, _ installed: String) -> String {
        String(format: loc("cli.install.wizard_message_versions"), bundled, installed)
    }
    static func cliInstallBundledVersion(_ version: String) -> String {
        String(format: loc("cli.install.bundled_version"), version)
    }
    static func cliInstallInstalledVersion(_ version: String) -> String {
        String(format: loc("cli.install.installed_version"), version)
    }
    static func cliInstallInstalledPath(_ path: String) -> String {
        String(format: loc("cli.install.installed_path"), path)
    }
    static func cliInstallTarget(_ directory: String) -> String {
        String(format: loc("cli.install.target"), directory)
    }

    static var cancelAction: String { loc("action.cancel") }
    static var closeAction:  String { loc("action.close") }

    static var noticeSwitchRestart: String { loc("notice.switch_restart") }
    static var noticeActiveChanged: String { loc("notice.active_changed") }

    static var privacyTitle:      String { loc("privacy.title") }
    static var privacyMessage:    String { loc("privacy.message") }
    static var privacyContinue:   String { loc("privacy.continue") }
    static var privacyLocalOnly:  String { loc("privacy.local_only") }
    static var privacyCancel:     String { loc("privacy.cancel") }

    static func removeConfirmTitle(_ alias: String) -> String {
        String(format: loc("row.remove_confirm_title"), alias)
    }
    static func removeConfirmMessage(_ email: String) -> String {
        String(format: loc("row.remove_confirm_message"), email)
    }
    static var removeConfirmButton: String { loc("row.remove_confirm_button") }

    static var statusLoading:    String { loc("status.loading") }
    static var statusRefreshing: String { loc("status.refreshing") }
    static var statusError:      String { loc("status.error") }
    static var statusDefault:    String { loc("status.default") }
    static var quit:             String { loc("quit") }

    static var settingsGeneral:         String { loc("settings.general") }
    static var settingsAbout:           String { loc("settings.about") }
    static var settingsLanguage:        String { loc("settings.language") }
    static var settingsAccounts:        String { loc("settings.accounts") }
    static var settingsConfirmSwitch:   String { loc("settings.confirm_switch") }
    static var settingsRefreshInterval: String { loc("settings.refresh_interval") }
    static var settingsLaunchAtLogin:   String { loc("settings.launch_at_login") }
    static var settingsAboutTitle:      String { loc("settings.about.title") }
    static var settingsAboutSubtitle:   String { loc("settings.about.subtitle") }
    static var settingsVersion: String {
        // 版本号来自打包时写入的 Info.plist(0.2.0 起参数化)。
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.2.0"
        return String(format: loc("settings.version"), version)
    }
    static var settingsLangSystem:      String { loc("settings.lang.system") }
    static var settingsLangNote:        String { loc("settings.lang.note") }
    static var settingsCliPath:         String { loc("settings.cli_path") }
    static var settingsCliPathPlaceholder: String { loc("settings.cli_path_placeholder") }
    static var settingsCliPathNote:     String { loc("settings.cli_path_note") }
    static var settingsCliPathInvalid:  String { loc("settings.cli_path_invalid") }
    static var settingsCliPathReveal:   String { loc("settings.cli_path_reveal") }
    static var settingsCliPathClear:    String { loc("settings.cli_path_clear") }

    static func settingsLowThreshold(_ pct: Int) -> String {
        String(format: loc("settings.low_threshold"), pct)
    }

    static func planName(_ raw: String) -> String {
        loc("plan.\(raw.lowercased())")
    }

    static var cliNotFound:     String { loc("cli.not_found") }
    static var cliInvalidOutput: String { loc("cli.invalid_output") }
    static var cliStateUncertain: String { loc("cli.state_uncertain") }

    static func cliExitCode(_ code: Int32) -> String {
        String(format: loc("cli.exit_code"), code)
    }

    static func cliUnsupportedSchema(_ version: Int) -> String {
        String(format: loc("cli.unsupported_schema"), version)
    }

    static func cliMissingCapability(_ command: String, _ version: String?) -> String {
        String(format: loc("cli.missing_capability"), version ?? "?", command)
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
        "row.removing": "Removing…",
        "row.remove_confirm_title": "Remove %@?",
        "row.remove_confirm_message": "This deletes the stored account %@. This cannot be undone.",
        "row.remove_confirm_button": "Remove",
        "header.refresh_api": "Refresh (API)",
        "header.refresh_local": "Refresh (Local Only)",
        "notice.switch_restart": "Switched. Restart Codex CLI / Codex App for the new account to take effect.",
        "notice.active_changed": "The active account was removed; another account is now active.",
        "privacy.title": "Refresh Uses ChatGPT API",
        "privacy.message": "API-backed refresh contacts ChatGPT endpoints using the active account token. See the project documentation for details.",
        "privacy.continue": "Continue",
        "privacy.local_only": "Local Only",
        "privacy.cancel": "Cancel",
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
        "settings.version": "Version %@",
        "settings.lang.system": "System Default",
        "settings.lang.note": "Language changes take effect on next launch.",
        "settings.cli_path": "codex-auth Path",
        "settings.cli_path_placeholder": "/opt/homebrew/bin/codex-auth",
        "settings.cli_path_note": "Overrides CLI discovery. Leave empty to use the bundled or PATH codex-auth.",
        "settings.cli_path_invalid": "Not an executable file",
        "settings.cli_path_reveal": "Reveal in Finder",
        "settings.cli_path_clear": "Clear",
        "plan.free": "Free", "plan.plus": "Plus", "plan.pro": "Pro",
        "plan.business": "Business", "plan.enterprise": "Enterprise",
        "plan.edu": "Edu", "plan.unknown": "Unknown",
        "cli.not_found": "codex-auth CLI not found",
        "cli.invalid_output": "Invalid CLI output",
        "cli.exit_code": "CLI exited with code %lld",
        "cli.unsupported_schema": "Unsupported JSON API schema %lld; update codex-auth",
        "cli.missing_capability": "Installed codex-auth %@ does not support %@ --json; update the CLI",
        "cli.state_uncertain": "CLI reported uncertain state; refresh to continue",
        "row.edit_alias": "Edit Alias…",
        "header.add_import": "Import auth.json…",
        "header.add_export": "Export Accounts…",
        "header.add.ax": "Add account",
        "alias.set_title": "Set Alias",
        "alias.rename_title": "Rename Alias",
        "alias.placeholder": "work",
        "alias.save_action": "Save",
        "alias.clear_action": "Clear Alias",
        "alias.optional_label": "Alias (optional, single file only)",
        "alias.invalid_empty": "Alias cannot be empty; use Clear Alias to remove one.",
        "alias.invalid_digits": "Alias cannot be only digits.",
        "alias.invalid_control": "Alias cannot contain control characters.",
        "import.title": "Import Accounts",
        "import.mode_label": "Format",
        "import.mode_standard": "Codex auth.json",
        "import.mode_cpa": "CLIProxyAPI (CPA)",
        "import.no_path": "No file selected",
        "import.choose_action": "Choose file or directory…",
        "import.advanced_label": "Advanced",
        "import.purge_action": "Rebuild registry from snapshots (purge)",
        "import.purge_warning": "Purge rebuilds the registry, resets stored usage and re-derives the active account. Use only to recover an out-of-sync registry.",
        "import.run_action": "Import",
        "import.summary": "%lld imported · %lld updated · %lld skipped",
        "import.status.imported": "imported",
        "import.status.updated": "updated",
        "import.status.skipped": "skipped",
        "export.title": "Export Accounts",
        "export.format_label": "Format",
        "export.format_standard": "Codex snapshots",
        "export.format_cpa": "CLIProxyAPI (CPA)",
        "export.no_path": "Default backup directory",
        "export.choose_action": "Choose destination…",
        "export.run_action": "Export",
        "export.reveal_action": "Reveal in Finder",
        "export.consent_title": "Export Contains Login Credentials",
        "export.consent_message": "Exported files contain login credentials. Store them somewhere safe.",
        "export.consent_confirm": "Export",
        "export.summary": "%lld exported · %lld skipped",
        "empty.title": "No accounts yet",
        "empty.message": "Import an auth.json file to get started, or sign in later via Login.",
        "empty.import_action": "Import auth.json…",
        "empty.login_action": "Sign in…",
        "header.add_login": "Sign in…",
        "header.launch_app": "Launch Codex App",
        "header.switch_previous": "Switch to Previous Account",
        "settings.notify_threshold": "Notify when capacity crosses the threshold",
        "settings.network_only": "Background refresh only when online",
        "maintenance.title": "Maintenance",
        "maintenance.clean_action": "Clean Backups",
        "maintenance.clean_description": "Delete backup and stale files under accounts/.",
        "maintenance.live_interval": "Live TUI refresh interval",
        "maintenance.clean_summary": "Cleaned: %lld auth backups · %lld registry backups · %lld stale files",
        "notification.threshold_title": "Codex capacity running low",
        "notification.threshold_body": "%@ has %lld%% remaining capacity.",
        "login.title": "Sign in with ChatGPT",
        "login.waiting": "Waiting for device authorization…",
        "login.step_open_link": "1. Open this link and sign in",
        "login.step_enter_code": "2. Enter this one-time code",
        "login.copy_code": "Copy Code",
        "login.open_browser": "Open Browser",
        "login.completed": "Signed in. The new account is active.",
        "login.retry": "Retry",
        "login.terminal_fallback": "Open in Terminal",
        "login.failed_generic": "Login failed.",
        "app.launch.launched": "Codex App launched.",
        "app.launch.already_running": "Codex App is already running.",
        "cli.install.title": "Command Line Tool",
        "cli.install.action": "Install / Update codex-auth",
        "cli.install.note": "Installs the bundled codex-auth into a directory on the default PATH and overwrites the local version with the bundled one.",
        "cli.install.not_installed": "Not installed on PATH",
        "cli.install.success": "codex-auth installed/updated.",
        "cli.install.bundled_missing": "Bundled codex-auth binary missing.",
        "cli.install.privileged_failed": "Administrator install failed.",
        "cli.install.path_hint": "~/.local/bin is not on the default PATH. Add it to your shell profile to use codex-auth from a terminal.",
        "cli.install.wizard_title": "Install Command Line Tool",
        "cli.install.wizard_message": "Install the bundled codex-auth to a directory on the default PATH? It overwrites the local version with the bundled one.",
        "cli.install.wizard_install": "Install",
        "cli.install.wizard_skip": "Skip",
        "cli.install.verify_failed": "Installed binary failed verification.",
        "cli.install.downgrade_title": "Replace Newer codex-auth?",
        "cli.install.downgrade_confirm": "Replace",
        "cli.install.wizard_message_versions": "Bundled: %@ · Installed: %@. Installing overwrites the local version with the bundled one.",

        "cli.install.bundled_version": "Bundled: %@",
        "cli.install.installed_version": "Installed: %@",
        "cli.install.installed_path": "At: %@",
        "cli.install.target": "Install target: %@",
        "action.cancel": "Cancel",
        "action.close": "Close",
        "settings.accounts": "Accounts",
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
        "row.removing": "移除中…",
        "row.remove_confirm_title": "移除 %@?",
        "row.remove_confirm_message": "将删除已存储的账号 %@。此操作不可撤销。",
        "row.remove_confirm_button": "移除",
        "header.refresh_api": "刷新(API)",
        "header.refresh_local": "刷新(仅本地)",
        "notice.switch_restart": "已切换。重启 Codex CLI / Codex App 后新账号生效。",
        "notice.active_changed": "活跃账号已被移除;另一账号现为活跃账号。",
        "privacy.title": "刷新会调用 ChatGPT API",
        "privacy.message": "API 刷新会使用当前账号令牌访问 ChatGPT 端点。详见项目文档。",
        "privacy.continue": "继续",
        "privacy.local_only": "仅本地",
        "privacy.cancel": "取消",
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
        "settings.version": "版本 %@",
        "settings.lang.system": "跟随系统",
        "settings.lang.note": "语言更改将在下次启动时生效",
        "settings.cli_path": "codex-auth 路径",
        "settings.cli_path_placeholder": "/opt/homebrew/bin/codex-auth",
        "settings.cli_path_note": "覆盖 CLI 查找。留空则使用内置或 PATH 中的 codex-auth。",
        "settings.cli_path_invalid": "不是可执行文件",
        "settings.cli_path_reveal": "在访达中显示",
        "settings.cli_path_clear": "清除",
        "plan.free": "Free", "plan.plus": "Plus", "plan.pro": "Pro",
        "plan.business": "Business", "plan.enterprise": "Enterprise",
        "plan.edu": "Edu", "plan.unknown": "未知",
        "cli.not_found": "未找到 codex-auth CLI",
        "cli.invalid_output": "CLI 输出无效",
        "cli.exit_code": "CLI 退出码 %lld",
        "cli.unsupported_schema": "不支持的 JSON API schema %lld;请更新 codex-auth",
        "cli.missing_capability": "已安装的 codex-auth %@ 不支持 %@ --json;请更新 CLI",
        "cli.state_uncertain": "CLI 报告状态不确定;请刷新后继续",
        "row.edit_alias": "编辑别名…",
        "header.add_import": "导入 auth.json…",
        "header.add_export": "导出账号…",
        "header.add.ax": "添加账号",
        "alias.set_title": "设置别名",
        "alias.rename_title": "重命名别名",
        "alias.placeholder": "work",
        "alias.save_action": "保存",
        "alias.clear_action": "清除别名",
        "alias.optional_label": "别名(可选,仅单文件)",
        "alias.invalid_empty": "别名不能为空;如需移除请使用「清除别名」。",
        "alias.invalid_digits": "别名不能全为数字。",
        "alias.invalid_control": "别名不能包含控制字符。",
        "import.title": "导入账号",
        "import.mode_label": "格式",
        "import.mode_standard": "Codex auth.json",
        "import.mode_cpa": "CLIProxyAPI (CPA)",
        "import.no_path": "未选择文件",
        "import.choose_action": "选择文件或目录…",
        "import.advanced_label": "高级",
        "import.purge_action": "从快照重建注册表(purge)",
        "import.purge_warning": "Purge 会重建注册表、重置已存储用量并重新推导活跃账号。仅在注册表与磁盘快照失步时用于恢复。",
        "import.run_action": "导入",
        "import.summary": "导入 %lld · 更新 %lld · 跳过 %lld",
        "import.status.imported": "已导入",
        "import.status.updated": "已更新",
        "import.status.skipped": "已跳过",
        "export.title": "导出账号",
        "export.format_label": "格式",
        "export.format_standard": "Codex 快照",
        "export.format_cpa": "CLIProxyAPI (CPA)",
        "export.no_path": "默认备份目录",
        "export.choose_action": "选择目标目录…",
        "export.run_action": "导出",
        "export.reveal_action": "在访达中显示",
        "export.consent_title": "导出内容包含登录凭据",
        "export.consent_message": "导出的文件包含登录凭据。请妥善保存。",
        "export.consent_confirm": "导出",
        "export.summary": "导出 %lld · 跳过 %lld",
        "empty.title": "暂无账号",
        "empty.message": "导入 auth.json 文件开始使用,或稍后通过登录添加。",
        "empty.import_action": "导入 auth.json…",
        "empty.login_action": "登录…",
        "header.add_login": "登录…",
        "header.launch_app": "启动 Codex App",
        "header.switch_previous": "切回上一个账号",
        "settings.notify_threshold": "容量越过阈值时通知",
        "settings.network_only": "仅在线时后台刷新",
        "maintenance.title": "维护",
        "maintenance.clean_action": "清理备份",
        "maintenance.clean_description": "删除 accounts/ 下的备份与过期文件。",
        "maintenance.live_interval": "Live TUI 刷新间隔",
        "maintenance.clean_summary": "已清理:%lld 个 auth 备份 · %lld 个 registry 备份 · %lld 个过期文件",
        "notification.threshold_title": "Codex 容量偏低",
        "notification.threshold_body": "%@ 剩余容量 %lld%%。",
        "login.title": "使用 ChatGPT 登录",
        "login.waiting": "等待设备授权…",
        "login.step_open_link": "1. 打开此链接并登录",
        "login.step_enter_code": "2. 输入此一次性验证码",
        "login.copy_code": "复制验证码",
        "login.open_browser": "打开浏览器",
        "login.completed": "已登录,新账号已激活。",
        "login.retry": "重试",
        "login.terminal_fallback": "在终端中打开",
        "login.failed_generic": "登录失败。",
        "app.launch.launched": "Codex App 已启动。",
        "app.launch.already_running": "Codex App 已在运行。",
        "cli.install.title": "命令行工具",
        "cli.install.action": "安装 / 更新 codex-auth",
        "cli.install.note": "将内置 codex-auth 安装到默认 PATH 目录,并用内置版本覆盖本地版本。",
        "cli.install.not_installed": "PATH 中未安装",
        "cli.install.success": "codex-auth 已安装/更新。",
        "cli.install.bundled_missing": "缺少内置 codex-auth 二进制。",
        "cli.install.privileged_failed": "管理员安装失败。",
        "cli.install.path_hint": "~/.local/bin 不在默认 PATH 中。请将其加入 shell 配置后才能在终端使用 codex-auth。",
        "cli.install.wizard_title": "安装命令行工具",
        "cli.install.wizard_message": "将内置 codex-auth 安装到默认 PATH 目录?此操作会用内置版本覆盖本地版本。",
        "cli.install.wizard_install": "安装",
        "cli.install.wizard_skip": "跳过",
        "cli.install.verify_failed": "安装产物验证失败。",
        "cli.install.downgrade_title": "替换更新的 codex-auth?",
        "cli.install.downgrade_confirm": "替换",
        "cli.install.wizard_message_versions": "内置:%@ · 已安装:%@。安装会用内置版本覆盖本地版本。",

        "cli.install.bundled_version": "内置:%@",
        "cli.install.installed_version": "已安装:%@",
        "cli.install.installed_path": "路径:%@",
        "cli.install.target": "安装目标:%@",
        "action.cancel": "取消",
        "action.close": "关闭",
        "settings.accounts": "账号",
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
