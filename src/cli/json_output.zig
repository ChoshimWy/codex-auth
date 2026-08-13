const std = @import("std");
const io_util = @import("../core/io_util.zig");
const registry = @import("../registry/root.zig");
const results = @import("../workflows/results.zig");
const version = @import("../version.zig");

const schema_version: u32 = 1;

pub const supported_json_commands = [_][]const u8{ "list", "switch", "remove", "alias", "import", "export", "app", "login", "clean", "config" };

pub fn printListResult(result: *const results.ListResult) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeListResult(out, result);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printSwitchResult(result: *const results.SwitchResult) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeSwitchResult(out, result);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printRemoveResult(result: *const results.RemoveResult) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeRemoveResult(out, result);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printAliasResult(result: *const results.AliasResult, operation: []const u8) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeAliasResult(out, result, operation);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printVersionResult() !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeVersionResult(out);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printExportResult(summary: *const registry.ExportSummary, format: []const u8) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeExportResult(out, summary, format);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printAppResult(
    status: []const u8,
    app_id: ?[]const u8,
    codex_cli_path: ?[]const u8,
) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeAppResult(out, status, app_id, codex_cli_path);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printLoginAwaitingUser(verification_url: []const u8, user_code: []const u8) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeLoginAwaitingUser(out, verification_url, user_code);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printLoginCompleted(active_account_key: ?[]const u8, account: *const results.AccountView) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeLoginCompleted(out, active_account_key, account);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printLoginFailed(message: []const u8) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeLoginFailed(out, message);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printImportResult(
    report: *const registry.ImportReport,
    mode: []const u8,
    source: ?[]const u8,
    active_account_key: ?[]const u8,
    registry_rebuilt: ?bool,
) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeImportResult(out, report, mode, source, active_account_key, registry_rebuilt);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printError(code: []const u8, message: []const u8, candidates: ?[]const results.AccountView) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeError(out, code, message, candidates);
    try out.writeAll("\n");
    try out.flush();
}

pub fn printUsageError(message: []const u8) !void {
    try printError("usage", message, null);
}

pub fn printSelectorResolutionError(resolutions: []const results.SelectorResolutionView) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeSelectorResolutionError(out, resolutions);
    try out.writeAll("\n");
    try out.flush();
}

pub fn writeListResult(out: *std.Io.Writer, result: *const results.ListResult) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("list");
    try jw.objectField("active_account_key");
    try jw.write(result.active_account_key);
    try jw.objectField("accounts");
    try writeAccountArray(&jw, result.accounts);
    try jw.endObject();
}

pub fn writeSwitchResult(out: *std.Io.Writer, result: *const results.SwitchResult) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("switch");
    try jw.objectField("switched_to");
    try writeAccount(&jw, &result.switched_to);
    try jw.endObject();
}

pub fn writeRemoveResult(out: *std.Io.Writer, result: *const results.RemoveResult) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("remove");
    try jw.objectField("removed");
    try writeAccountArray(&jw, result.removed);
    try jw.objectField("new_active_account_key");
    try jw.write(result.new_active_account_key);
    try jw.endObject();
}

pub fn writeAliasResult(out: *std.Io.Writer, result: *const results.AliasResult, operation: []const u8) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("alias");
    try jw.objectField("operation");
    try jw.write(operation);
    try jw.objectField("updated");
    try writeAccount(&jw, &result.updated);
    try jw.endObject();
}

pub fn writeVersionResult(out: *std.Io.Writer) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("version");
    try jw.objectField("version");
    try jw.write(version.app_version);
    try jw.objectField("json_api_schema");
    try jw.write(schema_version);
    try jw.objectField("supported_commands");
    try jw.beginArray();
    for (supported_json_commands) |command_name| {
        try jw.write(command_name);
    }
    try jw.endArray();
    try jw.endObject();
}

pub fn writeExportResult(
    out: *std.Io.Writer,
    summary: *const registry.ExportSummary,
    format: []const u8,
) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("export");
    try jw.objectField("format");
    try jw.write(format);
    try jw.objectField("destination");
    try jw.write(summary.dest_path);
    try jw.objectField("exported_count");
    try jw.write(summary.exported);
    try jw.objectField("skipped_count");
    try jw.write(summary.skipped);
    try jw.endObject();
}

pub fn writeAppResult(
    out: *std.Io.Writer,
    status: []const u8,
    app_id: ?[]const u8,
    codex_cli_path: ?[]const u8,
) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("app");
    try jw.objectField("status");
    try jw.write(status);
    try jw.objectField("app_id");
    try jw.write(app_id);
    try jw.objectField("codex_cli_path");
    try jw.write(codex_cli_path);
    try jw.endObject();
}

pub fn writeImportResult(
    out: *std.Io.Writer,
    report: *const registry.ImportReport,
    mode: []const u8,
    source: ?[]const u8,
    active_account_key: ?[]const u8,
    registry_rebuilt: ?bool,
) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("import");
    try jw.objectField("mode");
    try jw.write(mode);
    try jw.objectField("source");
    try jw.write(source);
    try jw.objectField("results");
    try jw.beginArray();
    for (report.events.items) |*event| {
        try jw.beginObject();
        try jw.objectField("path");
        try jw.write(event.label);
        try jw.objectField("status");
        try jw.write(switch (event.outcome) {
            .imported => "imported",
            .updated => "updated",
            .skipped => "skipped",
        });
        try jw.objectField("email");
        try jw.write(event.detail);
        try jw.objectField("reason");
        try jw.write(event.reason);
        try jw.endObject();
    }
    try jw.endArray();
    try jw.objectField("imported_count");
    try jw.write(report.imported);
    try jw.objectField("updated_count");
    try jw.write(report.updated);
    try jw.objectField("skipped_count");
    try jw.write(report.skipped);
    try jw.objectField("active_account_key");
    try jw.write(active_account_key);
    if (registry_rebuilt) |rebuilt| {
        try jw.objectField("registry_rebuilt");
        try jw.write(rebuilt);
    }
    try jw.endObject();
}

pub fn writeLoginAwaitingUser(out: *std.Io.Writer, verification_url: []const u8, user_code: []const u8) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("login");
    try jw.objectField("mode");
    try jw.write("device_auth");
    try jw.objectField("phase");
    try jw.write("awaiting_user");
    try jw.objectField("verification_url");
    try jw.write(verification_url);
    try jw.objectField("user_code");
    try jw.write(user_code);
    try jw.endObject();
}

pub fn writeLoginCompleted(out: *std.Io.Writer, active_account_key: ?[]const u8, account: *const results.AccountView) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("login");
    try jw.objectField("mode");
    try jw.write("device_auth");
    try jw.objectField("phase");
    try jw.write("completed");
    try jw.objectField("active_account_key");
    try jw.write(active_account_key);
    try jw.objectField("account");
    try writeAccount(&jw, account);
    try jw.endObject();
}

pub fn writeLoginFailed(out: *std.Io.Writer, message: []const u8) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("login");
    try jw.objectField("mode");
    try jw.write("device_auth");
    try jw.objectField("phase");
    try jw.write("failed");
    try jw.objectField("message");
    try jw.write(message);
    try jw.endObject();
}

pub const CleanResultView = struct {
    target: []const u8,
    auth_backups_removed: ?usize = null,
    registry_backups_removed: ?usize = null,
    stale_snapshot_files_removed: ?usize = null,
    platform: ?[]const u8 = null,
    files_removed: ?usize = null,
};

pub fn printCleanResult(view: *const CleanResultView) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeCleanResult(out, view);
    try out.writeAll("\n");
    try out.flush();
}

pub fn writeCleanResult(out: *std.Io.Writer, view: *const CleanResultView) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("clean");
    try jw.objectField("target");
    try jw.write(view.target);
    try jw.objectField("auth_backups_removed");
    try jw.write(view.auth_backups_removed);
    try jw.objectField("registry_backups_removed");
    try jw.write(view.registry_backups_removed);
    try jw.objectField("stale_snapshot_files_removed");
    try jw.write(view.stale_snapshot_files_removed);
    try jw.objectField("platform");
    try jw.write(view.platform);
    try jw.objectField("files_removed");
    try jw.write(view.files_removed);
    try jw.endObject();
}

pub fn printConfigResult(section: []const u8, interval_seconds: u16) !void {
    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try writeConfigResult(out, section, interval_seconds);
    try out.writeAll("\n");
    try out.flush();
}

pub fn writeConfigResult(out: *std.Io.Writer, section: []const u8, interval_seconds: u16) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("command");
    try jw.write("config");
    try jw.objectField("section");
    try jw.write(section);
    try jw.objectField("interval_seconds");
    try jw.write(interval_seconds);
    try jw.endObject();
}

/// Maps an unhandled workflow error to the `registry_error` JSON error document
/// and a handled exit-code-1 error. `curl_unavailable` keeps its dedicated
/// code. Shared by every JSON mutation workflow.
pub fn printJsonWorkflowError(err: anyerror) anyerror {
    switch (err) {
        error.OutOfMemory => return err,
        error.CurlRequired => {
            try printError(
                "curl_unavailable",
                "curl is required for API-backed refresh. Install curl or use --skip-api.",
                null,
            );
            return err;
        },
        else => {
            try printError("registry_error", @errorName(err), null);
            return error.RegistryError;
        },
    }
}

/// Maps a persistence failure that occurred after a mutation began to the
/// `state_uncertain` JSON error document and a handled exit-code-1 error.
/// The message names the failed operation.
pub fn printJsonMutationError(err: anyerror, message: []const u8) anyerror {
    if (err == error.OutOfMemory) return err;
    try printError("state_uncertain", message, null);
    return error.StateUncertain;
}

pub fn writeError(
    out: *std.Io.Writer,
    code: []const u8,
    message: []const u8,
    candidates: ?[]const results.AccountView,
) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("error");
    try jw.beginObject();
    try jw.objectField("code");
    try jw.write(code);
    try jw.objectField("message");
    try jw.write(message);
    if (candidates) |items| {
        try jw.objectField("candidates");
        try writeAccountArray(&jw, items);
    }
    try jw.endObject();
    try jw.endObject();
}

pub fn writeSelectorResolutionError(
    out: *std.Io.Writer,
    resolutions: []const results.SelectorResolutionView,
) !void {
    var jw: std.json.Stringify = .{ .writer = out, .options = .{} };
    try jw.beginObject();
    try writeSchemaVersion(&jw);
    try jw.objectField("error");
    try jw.beginObject();
    try jw.objectField("code");
    try jw.write("selector_resolution_failed");
    try jw.objectField("message");
    try jw.write("one or more selectors could not be resolved");
    try jw.objectField("resolutions");
    try jw.beginArray();
    for (resolutions) |*resolution| {
        try writeSelectorResolution(&jw, resolution);
    }
    try jw.endArray();
    try jw.endObject();
    try jw.endObject();
}

fn writeSchemaVersion(jw: *std.json.Stringify) !void {
    try jw.objectField("schema_version");
    try jw.write(schema_version);
}

fn writeAccountArray(jw: *std.json.Stringify, accounts: []const results.AccountView) !void {
    try jw.beginArray();
    for (accounts) |*account| {
        try writeAccount(jw, account);
    }
    try jw.endArray();
}

fn writeAccount(jw: *std.json.Stringify, account: *const results.AccountView) !void {
    try jw.beginObject();
    try jw.objectField("number");
    try jw.write(account.number);
    try jw.objectField("account_key");
    try jw.write(account.account_key);
    try jw.objectField("email");
    try jw.write(account.email);
    try jw.objectField("alias");
    try jw.write(account.alias);
    try jw.objectField("account_name");
    try jw.write(account.account_name);
    try jw.objectField("plan");
    try writeOptionalText(jw, planName(account.plan));
    try jw.objectField("auth_mode");
    try writeOptionalText(jw, authModeName(account.auth_mode));
    try jw.objectField("active");
    try jw.write(account.active);
    try jw.objectField("created_at");
    try jw.write(account.created_at);
    try jw.objectField("last_used_at");
    try jw.write(account.last_used_at);
    try jw.objectField("usage");
    try writeUsage(jw, &account.usage);
    try jw.endObject();
}

fn writeUsage(jw: *std.json.Stringify, usage: *const results.UsageView) !void {
    try jw.beginObject();
    try jw.objectField("source");
    try jw.write(usageSourceName(usage.source));
    try jw.objectField("updated_at");
    try jw.write(usage.updated_at);
    try jw.objectField("primary");
    try writeWindow(jw, usage.primary);
    try jw.objectField("secondary");
    try writeWindow(jw, usage.secondary);
    try jw.objectField("credits");
    try writeCredits(jw, usage.credits);
    try jw.objectField("reset_credits");
    try jw.write(usage.reset_credits);
    try jw.objectField("refresh");
    try writeUsageRefresh(jw, &usage.refresh);
    try jw.endObject();
}

fn usageSourceName(source: results.UsageSource) []const u8 {
    return switch (source) {
        .api => "api",
        .local => "local",
        .cache => "cache",
        .none => "none",
    };
}

fn writeUsageRefresh(jw: *std.json.Stringify, refresh: *const results.UsageRefreshView) !void {
    try jw.beginObject();
    try jw.objectField("requested");
    try jw.write(refresh.requested);
    try jw.objectField("method");
    if (refresh.method) |method| {
        try jw.write(switch (method) {
            .api => "api",
            .local => "local",
        });
    } else {
        try jw.write(null);
    }
    try jw.objectField("status");
    try jw.write(switch (refresh.status) {
        .not_requested => "not_requested",
        .ok => "ok",
        .no_data => "no_data",
        .http_error => "http_error",
        .missing_auth => "missing_auth",
        .error_status => "error",
    });
    try jw.objectField("http_status");
    try jw.write(refresh.http_status);
    try jw.objectField("error_code");
    try jw.write(refresh.error_code);
    try jw.endObject();
}

fn writeWindow(jw: *std.json.Stringify, window: ?registry.RateLimitWindow) !void {
    const value = window orelse {
        try jw.write(null);
        return;
    };
    try jw.beginObject();
    try jw.objectField("used_percent");
    try jw.write(value.used_percent);
    try jw.objectField("window_minutes");
    try jw.write(value.window_minutes);
    try jw.objectField("resets_at");
    try jw.write(value.resets_at);
    try jw.endObject();
}

fn writeCredits(jw: *std.json.Stringify, credits: ?results.CreditsView) !void {
    const value = credits orelse {
        try jw.write(null);
        return;
    };
    try jw.beginObject();
    try jw.objectField("has_credits");
    try jw.write(value.has_credits);
    try jw.objectField("unlimited");
    try jw.write(value.unlimited);
    try jw.objectField("balance");
    try jw.write(value.balance);
    try jw.endObject();
}

fn writeOptionalText(jw: *std.json.Stringify, value: ?[]const u8) !void {
    if (value) |text| {
        try jw.write(text);
    } else {
        try jw.write(null);
    }
}

fn planName(plan: ?registry.PlanType) ?[]const u8 {
    const value = plan orelse return null;
    return switch (value) {
        .free => "free",
        .go => "go",
        .plus => "plus",
        .prolite => "prolite",
        .pro => "pro",
        .business => "business",
        .enterprise => "enterprise",
        .edu => "edu",
        .unknown => "unknown",
    };
}

fn writeSelectorResolution(
    jw: *std.json.Stringify,
    resolution: *const results.SelectorResolutionView,
) !void {
    try jw.beginObject();
    try jw.objectField("selector");
    try jw.write(resolution.selector);
    try jw.objectField("status");
    try jw.write(switch (resolution.status) {
        .resolved => "resolved",
        .ambiguous => "ambiguous",
        .not_found => "not_found",
    });
    try jw.objectField("account_key");
    try jw.write(resolution.account_key);
    try jw.objectField("candidates");
    try writeAccountArray(jw, resolution.candidates);
    try jw.endObject();
}

fn authModeName(auth_mode: ?registry.AuthMode) ?[]const u8 {
    const value = auth_mode orelse return null;
    return switch (value) {
        .chatgpt => "chatgpt",
        .apikey => "apikey",
    };
}
