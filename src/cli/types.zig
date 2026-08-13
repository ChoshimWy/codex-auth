pub const ApiMode = enum {
    default,
    force_api,
    skip_api,
};

pub const ListOptions = struct {
    live: bool = false,
    api_mode: ApiMode = .default,
    active_only: bool = false,
    json: bool = false,
};
pub const LoginOptions = struct {
    device_auth: bool = false,
    json: bool = false,
};
pub const ImportSource = enum { standard, cpa };
pub const ImportOptions = struct {
    auth_path: ?[]u8,
    alias: ?[]u8,
    purge: bool,
    source: ImportSource,
    json: bool = false,
};
pub const ExportFormat = enum { standard, cpa };
pub const ExportOptions = struct {
    dest_path: ?[]u8,
    format: ExportFormat,
    json: bool = false,
};
pub const SwitchTarget = union(enum) {
    picker,
    query: []u8,
    previous,
};
pub const SwitchOptions = struct {
    target: SwitchTarget = .picker,
    live: bool = false,
    api_mode: ApiMode = .default,
    json: bool = false,
};
pub const RemoveOptions = struct {
    selectors: [][]const u8,
    all: bool,
    live: bool = false,
    api_mode: ApiMode = .default,
    json: bool = false,
};
pub const AliasSetOptions = struct {
    selector: []u8,
    alias: []u8,
    json: bool = false,
};
pub const AliasClearOptions = struct {
    selector: []u8,
    json: bool = false,
};
pub const AliasOptions = union(enum) {
    set: AliasSetOptions,
    clear: AliasClearOptions,
};
pub const CleanTarget = enum { accounts, background };
pub const CleanOptions = struct {
    target: CleanTarget = .accounts,
    json: bool = false,
};
pub const LiveOptions = struct {
    interval_seconds: u16,
    json: bool = false,
};
pub const ConfigGetOptions = struct {
    json: bool = false,
};
pub const ConfigOptions = union(enum) { live: LiveOptions, get: ConfigGetOptions };
pub const AppAction = enum { launch };
pub const AppPlatform = enum { win, wsl, mac };
pub const VersionOptions = struct {
    json: bool = false,
};
pub const AppOptions = struct {
    action: AppAction,
    app_id: ?[]const u8 = null,
    codex_cli_path: ?[]const u8 = null,
    codex_home: ?[]const u8 = null,
    platform: ?AppPlatform = null,
    inherit_stdio: bool = false,
    json: bool = false,
};
pub const HelpTopic = enum {
    top_level,
    list,
    login,
    import_auth,
    export_auth,
    switch_account,
    remove_account,
    alias,
    clean,
    config,
    app,
};

pub const Command = union(enum) {
    list: ListOptions,
    login: LoginOptions,
    import_auth: ImportOptions,
    export_auth: ExportOptions,
    switch_account: SwitchOptions,
    remove_account: RemoveOptions,
    alias: AliasOptions,
    clean: CleanOptions,
    config: ConfigOptions,
    app: AppOptions,
    version: VersionOptions,
    help: HelpTopic,
};

pub const UsageError = struct {
    topic: HelpTopic,
    message: []u8,
    json: bool = false,
};

pub const ParseResult = union(enum) {
    command: Command,
    usage_error: UsageError,
};
