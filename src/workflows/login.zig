const std = @import("std");
const cli = @import("../cli/root.zig");
const registry = @import("../registry/root.zig");
const auth = @import("../auth/auth.zig");
const me_api = @import("../api/me.zig");
const account_names = @import("account_names.zig");
const app_runtime = @import("../core/runtime.zig");
const results = @import("results.zig");

const defaultAccountFetcher = account_names.defaultAccountFetcher;
const refreshAccountNamesAfterLogin = account_names.refreshAccountNamesAfterLogin;

fn loginScratchCodexHomeAlloc(allocator: std.mem.Allocator, codex_home: []const u8) ![]u8 {
    const stamp = std.Io.Timestamp.now(app_runtime.io(), .real).toMilliseconds();
    const name = try std.fmt.allocPrint(allocator, "login-{d}", .{stamp});
    defer allocator.free(name);
    return try std.fs.path.join(allocator, &[_][]const u8{ codex_home, "accounts", name });
}

pub fn handleLogin(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.LoginOptions) !void {
    if (opts.json) return handleLoginJson(allocator, codex_home, opts);

    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    if (reg.accounts.items.len > 0) {
        _ = try registry.syncActiveAccountFromAuth(allocator, codex_home, &reg);
    }

    try registry.ensureAccountsDir(allocator, codex_home);
    const login_codex_home = try loginScratchCodexHomeAlloc(allocator, codex_home);
    defer allocator.free(login_codex_home);
    defer std.Io.Dir.cwd().deleteTree(app_runtime.io(), login_codex_home) catch {};
    try registry.ensurePrivateDir(login_codex_home);

    try cli.login.runCodexLogin(opts, login_codex_home);

    const record_key = try completeLoginImport(allocator, codex_home, login_codex_home, &reg);
    defer allocator.free(record_key);
    try registry.saveRegistry(allocator, codex_home, &reg);
}

const login_json_uncertain_message =
    "the login operation could not be completed; stored state may have changed; run `list --json` before retrying";

fn handleLoginJson(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.LoginOptions) !void {
    var reg = registry.loadRegistry(allocator, codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer reg.deinit(allocator);
    if (reg.accounts.items.len > 0) {
        _ = registry.syncActiveAccountFromAuth(allocator, codex_home, &reg) catch |err|
            return cli.json_output.printJsonWorkflowError(err);
    }

    registry.ensureAccountsDir(allocator, codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    const login_codex_home = try loginScratchCodexHomeAlloc(allocator, codex_home);
    defer allocator.free(login_codex_home);
    defer std.Io.Dir.cwd().deleteTree(app_runtime.io(), login_codex_home) catch {};
    registry.ensurePrivateDir(login_codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);

    var captured = cli.login.spawnCodexLoginCapture(allocator, opts, login_codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer captured.deinit(allocator);
    errdefer captured.abandon();

    var device_info = cli.login.captureDeviceAuthInfo(allocator, &captured) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    if (device_info) |*info| {
        defer info.deinit(allocator);
        try cli.json_output.printLoginAwaitingUser(info.verification_url, info.user_code);
    } else {
        const term = captured.finish(allocator) catch |err|
            return cli.json_output.printJsonWorkflowError(err);
        const message = switch (term) {
            .exited => |code| if (code != 0)
                try std.fmt.allocPrint(allocator, "codex login failed with exit code {d}", .{code})
            else
                try allocator.dupe(u8, "codex login finished without device authorization details"),
            else => try allocator.dupe(u8, "codex login was terminated"),
        };
        defer allocator.free(message);
        try cli.json_output.printLoginFailed(message);
        return;
    }

    const term = captured.finish(allocator) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    switch (term) {
        .exited => |code| if (code != 0) {
            const message = try std.fmt.allocPrint(allocator, "codex login failed with exit code {d}", .{code});
            defer allocator.free(message);
            try cli.json_output.printLoginFailed(message);
            return;
        },
        else => {
            try cli.json_output.printLoginFailed("codex login was terminated");
            return;
        },
    }

    const record_key = completeLoginImport(allocator, codex_home, login_codex_home, &reg) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer allocator.free(record_key);
    registry.saveRegistry(allocator, codex_home, &reg) catch |err|
        return cli.json_output.printJsonMutationError(err, login_json_uncertain_message);

    var result = results.buildLoginResult(allocator, &reg, record_key) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer result.deinit(allocator);
    try cli.json_output.printLoginCompleted(result.active_account_key, &result.account);
}

/// Copies the scratch-home auth snapshot into the real codex home, imports
/// the account into the registry, and activates it. Mutates `reg` but does
/// not save; the caller persists with its own error handling.
fn completeLoginImport(
    allocator: std.mem.Allocator,
    codex_home: []const u8,
    login_codex_home: []const u8,
    reg: *registry.Registry,
) ![]u8 {
    const login_auth_path = try registry.activeAuthPath(allocator, login_codex_home);
    defer allocator.free(login_auth_path);

    const auth_path = try registry.activeAuthPath(allocator, codex_home);
    defer allocator.free(auth_path);
    try registry.copyManagedFile(login_auth_path, auth_path);

    const info = try auth.parseAuthInfo(allocator, auth_path);
    defer info.deinit(allocator);

    if (info.auth_mode == .apikey) {
        const api_key = info.openai_api_key orelse return error.MissingOpenAIAPIKey;
        var me = try me_api.fetchMeForApiKey(allocator, api_key);
        defer me.deinit(allocator);

        const record_key = try registry.apiKeyAccountKeyAlloc(allocator, me.user_id, api_key);
        errdefer allocator.free(record_key);
        const dest = try registry.accountAuthPath(allocator, codex_home, record_key);
        defer allocator.free(dest);

        try registry.ensureAccountsDir(allocator, codex_home);
        try registry.copyManagedFile(auth_path, dest);

        const record = try registry.accountFromApiKeyMe(allocator, "", &info, &me);
        try registry.upsertAccount(allocator, reg, record);
        try registry.setActiveAccountKey(allocator, reg, record_key);
        return record_key;
    }

    const email = info.email orelse return error.MissingEmail;
    _ = email;
    const record_key = info.record_key orelse return error.MissingChatgptUserId;
    const dest = try registry.accountAuthPath(allocator, codex_home, record_key);
    defer allocator.free(dest);

    try registry.ensureAccountsDir(allocator, codex_home);
    try registry.copyManagedFile(auth_path, dest);

    const record = try registry.accountFromAuth(allocator, "", &info);
    try registry.upsertAccount(allocator, reg, record);
    try registry.setActiveAccountKey(allocator, reg, record_key);
    _ = try refreshAccountNamesAfterLogin(allocator, reg, &info, defaultAccountFetcher);
    return try allocator.dupe(u8, record_key);
}
