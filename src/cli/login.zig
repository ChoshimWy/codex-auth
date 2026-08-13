const builtin = @import("builtin");
const std = @import("std");
const http_env = @import("../api/http_env.zig");
const http_executable = @import("../api/http_executable.zig");
const app_runtime = @import("../core/runtime.zig");
const io_util = @import("../core/io_util.zig");
const types = @import("types.zig");
const output = @import("output.zig");

pub const WindowsCodexPathKind = enum {
    exe,
    cmd,
    bat,
    ps1,
};

pub const WindowsCodexPath = struct {
    path: []u8,
    kind: WindowsCodexPathKind,

    pub fn deinit(self: *WindowsCodexPath, allocator: std.mem.Allocator) void {
        allocator.free(self.path);
    }
};

const CodexLaunch = struct {
    owned_paths: [1]?[]u8 = .{null},
    argv_storage: [9][]const u8 = undefined,
    argv_len: usize = 0,

    fn argv(self: *const CodexLaunch) []const []const u8 {
        return self.argv_storage[0..self.argv_len];
    }

    fn deinit(self: *CodexLaunch, allocator: std.mem.Allocator) void {
        for (self.owned_paths) |maybe_path| {
            if (maybe_path) |path| allocator.free(path);
        }
    }
};

const WindowsCodexPathList = std.ArrayList(WindowsCodexPath);

const PowerShellHost = enum {
    powershell,
    pwsh,
};

pub const RetryableWindowsCodexBuildError = enum {
    powershell_not_found,
};

pub const WindowsCodexLaunchFailure = struct {
    hint_name: []const u8,
    err: anyerror,
};

pub fn codexLoginArgs(opts: types.LoginOptions) []const []const u8 {
    return if (opts.device_auth)
        &[_][]const u8{ "codex", "login", "--device-auth" }
    else
        &[_][]const u8{ "codex", "login" };
}

pub fn resolveWindowsCodexPathEntryAlloc(
    allocator: std.mem.Allocator,
    entry: []const u8,
) !?WindowsCodexPath {
    var candidates = try collectWindowsCodexPathEntriesAlloc(allocator, &[_][]const u8{entry});
    errdefer deinitWindowsCodexPathList(allocator, &candidates);

    if (candidates.items.len == 0) return null;

    const resolved = candidates.orderedRemove(0);
    deinitWindowsCodexPathList(allocator, &candidates);
    return resolved;
}

pub fn resolveWindowsCodexPathEntriesAlloc(
    allocator: std.mem.Allocator,
    entries: []const []const u8,
) !?WindowsCodexPath {
    var candidates = try collectWindowsCodexPathEntriesAlloc(allocator, entries);
    errdefer deinitWindowsCodexPathList(allocator, &candidates);

    if (candidates.items.len == 0) return null;

    const resolved = candidates.orderedRemove(0);
    deinitWindowsCodexPathList(allocator, &candidates);
    return resolved;
}

fn resolvePathEntryCandidateAlloc(
    allocator: std.mem.Allocator,
    entry: []const u8,
    candidate_name: []const u8,
) !?[]u8 {
    const candidate = try std.fs.path.join(allocator, &[_][]const u8{ entry, candidate_name });
    errdefer allocator.free(candidate);

    if (!accessPath(candidate)) {
        allocator.free(candidate);
        return null;
    }

    return candidate;
}

fn windowsCodexCandidateName(kind: WindowsCodexPathKind) []const u8 {
    return switch (kind) {
        .exe => "codex.exe",
        .cmd => "codex.cmd",
        .bat => "codex.bat",
        .ps1 => "codex.ps1",
    };
}

fn appendWindowsCodexPathCandidateIfAvailable(
    allocator: std.mem.Allocator,
    candidates: *WindowsCodexPathList,
    entry: []const u8,
    kind: WindowsCodexPathKind,
) !void {
    if (try resolvePathEntryCandidateAlloc(allocator, entry, windowsCodexCandidateName(kind))) |path| {
        try candidates.append(allocator, .{ .path = path, .kind = kind });
    }
}

fn appendWindowsCodexPathEntryCandidatesAlloc(
    allocator: std.mem.Allocator,
    native_candidates: *WindowsCodexPathList,
    ps1_candidates: *WindowsCodexPathList,
    entry: []const u8,
) !void {
    try appendWindowsCodexPathCandidateIfAvailable(allocator, native_candidates, entry, .exe);
    try appendWindowsCodexPathCandidateIfAvailable(allocator, native_candidates, entry, .cmd);
    try appendWindowsCodexPathCandidateIfAvailable(allocator, native_candidates, entry, .bat);
    try appendWindowsCodexPathCandidateIfAvailable(allocator, ps1_candidates, entry, .ps1);
}

fn deinitWindowsCodexPathList(allocator: std.mem.Allocator, candidates: *WindowsCodexPathList) void {
    for (candidates.items) |*candidate| candidate.deinit(allocator);
    candidates.deinit(allocator);
}

fn appendWindowsCodexPathLists(
    allocator: std.mem.Allocator,
    dst: *WindowsCodexPathList,
    src: *WindowsCodexPathList,
) !void {
    try dst.appendSlice(allocator, src.items);
    src.clearRetainingCapacity();
}

fn collectWindowsCodexPathEntriesAlloc(
    allocator: std.mem.Allocator,
    entries: []const []const u8,
) !WindowsCodexPathList {
    var native_candidates: WindowsCodexPathList = .empty;
    errdefer deinitWindowsCodexPathList(allocator, &native_candidates);
    var ps1_candidates: WindowsCodexPathList = .empty;
    errdefer deinitWindowsCodexPathList(allocator, &ps1_candidates);

    for (entries) |entry| {
        if (entry.len == 0) continue;
        try appendWindowsCodexPathEntryCandidatesAlloc(allocator, &native_candidates, &ps1_candidates, entry);
    }

    try appendWindowsCodexPathLists(allocator, &native_candidates, &ps1_candidates);
    ps1_candidates.deinit(allocator);
    return native_candidates;
}

fn accessPath(path: []const u8) bool {
    if (std.fs.path.isAbsolute(path)) {
        std.Io.Dir.accessAbsolute(app_runtime.io(), path, .{}) catch return false;
        return true;
    }

    std.Io.Dir.cwd().access(app_runtime.io(), path, .{}) catch return false;
    return true;
}

fn resolveWindowsCodexPathValueAlloc(
    allocator: std.mem.Allocator,
    path_value: []const u8,
    native_candidates: *WindowsCodexPathList,
    ps1_candidates: *WindowsCodexPathList,
) !void {
    var path_it = std.mem.splitScalar(u8, path_value, std.fs.path.delimiter);
    while (path_it.next()) |entry| {
        if (entry.len == 0) continue;
        try appendWindowsCodexPathEntryCandidatesAlloc(allocator, native_candidates, ps1_candidates, entry);
    }
}

fn collectWindowsCodexPathsAlloc(allocator: std.mem.Allocator) !WindowsCodexPathList {
    var native_candidates: WindowsCodexPathList = .empty;
    errdefer deinitWindowsCodexPathList(allocator, &native_candidates);
    var ps1_candidates: WindowsCodexPathList = .empty;
    errdefer deinitWindowsCodexPathList(allocator, &ps1_candidates);

    const path_value = http_env.getEnvVarOwned(allocator, "PATH") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            try appendWindowsCodexPathLists(allocator, &native_candidates, &ps1_candidates);
            ps1_candidates.deinit(allocator);
            return native_candidates;
        },
        else => return err,
    };
    defer allocator.free(path_value);

    try resolveWindowsCodexPathValueAlloc(allocator, path_value, &native_candidates, &ps1_candidates);
    try appendWindowsCodexPathLists(allocator, &native_candidates, &ps1_candidates);
    ps1_candidates.deinit(allocator);
    return native_candidates;
}

fn resolveOptionalExecutableAlloc(
    allocator: std.mem.Allocator,
    executable: []const u8,
) !?[]u8 {
    return http_executable.ensureExecutableAvailableAlloc(allocator, executable) catch |err| switch (err) {
        error.ExecutableRequired => null,
        else => return err,
    };
}

fn resolveWindowsPowerShellExecutableAlloc(allocator: std.mem.Allocator) ![]u8 {
    if (try resolveOptionalExecutableAlloc(allocator, "powershell.exe")) |path| return path;
    if (try resolveOptionalExecutableAlloc(allocator, "pwsh.exe")) |path| return path;
    return error.PowerShellNotFound;
}

fn resolveWindowsPowerShellExecutableForHostAlloc(
    allocator: std.mem.Allocator,
    host: PowerShellHost,
) ![]u8 {
    return switch (host) {
        .powershell => (try resolveOptionalExecutableAlloc(allocator, "powershell.exe")) orelse error.PowerShellNotFound,
        .pwsh => (try resolveOptionalExecutableAlloc(allocator, "pwsh.exe")) orelse error.PowerShellNotFound,
    };
}

fn buildCodexLaunchAlloc(allocator: std.mem.Allocator, opts: types.LoginOptions) !CodexLaunch {
    _ = allocator;
    var launch = CodexLaunch{};
    const args = codexLoginArgs(opts);
    @memcpy(launch.argv_storage[0..args.len], args);
    launch.argv_len = args.len;
    return launch;
}

fn buildWindowsCodexLaunchAlloc(
    allocator: std.mem.Allocator,
    resolved: *const WindowsCodexPath,
    opts: types.LoginOptions,
) !CodexLaunch {
    switch (resolved.kind) {
        .exe, .cmd, .bat => {
            var launch = CodexLaunch{};
            launch.argv_storage[0] = resolved.path;
            launch.argv_storage[1] = "login";
            launch.argv_len = 2;
            if (opts.device_auth) {
                launch.argv_storage[2] = "--device-auth";
                launch.argv_len = 3;
            }
            return launch;
        },
        .ps1 => {
            return buildWindowsPowerShellCodexLaunchAlloc(allocator, resolved.path, opts, null);
        },
    }
}

fn buildWindowsPowerShellCodexLaunchAlloc(
    allocator: std.mem.Allocator,
    script_path: []const u8,
    opts: types.LoginOptions,
    preferred_host: ?PowerShellHost,
) !CodexLaunch {
    const powershell = if (preferred_host) |host|
        try resolveWindowsPowerShellExecutableForHostAlloc(allocator, host)
    else
        try resolveWindowsPowerShellExecutableAlloc(allocator);
    errdefer allocator.free(powershell);

    var launch = CodexLaunch{ .owned_paths = .{powershell} };
    launch.argv_storage[0] = powershell;
    launch.argv_storage[1] = "-NoLogo";
    launch.argv_storage[2] = "-NoProfile";
    launch.argv_storage[3] = "-ExecutionPolicy";
    launch.argv_storage[4] = "Bypass";
    launch.argv_storage[5] = "-File";
    launch.argv_storage[6] = script_path;
    launch.argv_storage[7] = "login";
    launch.argv_len = 8;
    if (opts.device_auth) {
        launch.argv_storage[8] = "--device-auth";
        launch.argv_len = 9;
    }
    return launch;
}

fn ensureCodexLoginSucceeded(term: std.process.Child.Term) !void {
    switch (term) {
        .exited => |code| {
            if (code == 0) return;
            return error.CodexLoginFailed;
        },
        else => return error.CodexLoginFailed,
    }
}

fn writeCodexLoginLaunchFailureHint(err_name: []const u8) !void {
    var stderr: io_util.Stderr = undefined;
    stderr.init();
    const out = stderr.out();
    try output.writeCodexLoginLaunchFailureHintTo(out, err_name, stderr.color_enabled);
    try out.flush();
}

fn retryableWindowsCodexBuildErrorName(err: RetryableWindowsCodexBuildError) []const u8 {
    return switch (err) {
        .powershell_not_found => "PowerShellNotFound",
    };
}

fn retryableWindowsCodexBuildErrorValue(err: RetryableWindowsCodexBuildError) anyerror {
    return switch (err) {
        .powershell_not_found => error.PowerShellNotFound,
    };
}

fn shouldRetryWindowsCodexBuild(err: anyerror, kind: WindowsCodexPathKind) ?RetryableWindowsCodexBuildError {
    return switch (err) {
        error.PowerShellNotFound => switch (kind) {
            .ps1 => .powershell_not_found,
            else => null,
        },
        else => null,
    };
}

pub fn finalRetryableWindowsCodexLaunchFailure(
    last_retryable_spawn_error: ?std.process.SpawnError,
    last_retryable_build_error: ?RetryableWindowsCodexBuildError,
) ?WindowsCodexLaunchFailure {
    if (last_retryable_build_error) |build_err| {
        if (last_retryable_spawn_error) |spawn_err| {
            if (spawn_err != error.FileNotFound) {
                return .{
                    .hint_name = @errorName(spawn_err),
                    .err = spawn_err,
                };
            }
        }

        return .{
            .hint_name = retryableWindowsCodexBuildErrorName(build_err),
            .err = retryableWindowsCodexBuildErrorValue(build_err),
        };
    }

    if (last_retryable_spawn_error) |spawn_err| {
        return .{
            .hint_name = @errorName(spawn_err),
            .err = spawn_err,
        };
    }

    return null;
}

fn shouldRetryWindowsCodexLaunch(err: std.process.SpawnError, kind: WindowsCodexPathKind) bool {
    return switch (err) {
        error.FileNotFound => true,
        error.AccessDenied => switch (kind) {
            .exe, .cmd, .bat, .ps1 => true,
        },
        else => false,
    };
}

fn launchUsesWindowsPowerShellHost(launch: *const CodexLaunch) bool {
    if (launch.argv_len == 0) return false;
    return std.ascii.eqlIgnoreCase(std.fs.path.basename(launch.argv_storage[0]), "powershell.exe");
}

pub fn runCodexLogin(opts: types.LoginOptions, codex_home: []const u8) !void {
    var env_map = try app_runtime.currentEnviron().createMap(std.heap.page_allocator);
    defer env_map.deinit();
    try env_map.put("CODEX_HOME", codex_home);

    if (builtin.os.tag == .windows) {
        var candidates = try collectWindowsCodexPathsAlloc(std.heap.page_allocator);
        defer deinitWindowsCodexPathList(std.heap.page_allocator, &candidates);

        if (candidates.items.len == 0) {
            writeCodexLoginLaunchFailureHint("FileNotFound") catch {};
            return error.FileNotFound;
        }

        var last_retryable_spawn_error: ?std.process.SpawnError = null;
        var last_retryable_build_error: ?RetryableWindowsCodexBuildError = null;
        candidate_loop: for (candidates.items) |*candidate| {
            var launch = buildWindowsCodexLaunchAlloc(std.heap.page_allocator, candidate, opts) catch |err| {
                if (shouldRetryWindowsCodexBuild(err, candidate.kind)) |retryable_err| {
                    last_retryable_build_error = retryable_err;
                    continue :candidate_loop;
                }
                writeCodexLoginLaunchFailureHint(@errorName(err)) catch {};
                return err;
            };

            var child = child: {
                spawn_attempt: while (true) {
                    break :child std.process.spawn(app_runtime.io(), .{
                        .argv = launch.argv(),
                        .environ_map = &env_map,
                        .stdin = .inherit,
                        .stdout = .inherit,
                        .stderr = .inherit,
                    }) catch |err| {
                        if (candidate.kind == .ps1 and launchUsesWindowsPowerShellHost(&launch) and err == error.AccessDenied) {
                            last_retryable_spawn_error = err;
                            launch.deinit(std.heap.page_allocator);
                            launch = buildWindowsPowerShellCodexLaunchAlloc(
                                std.heap.page_allocator,
                                candidate.path,
                                opts,
                                .pwsh,
                            ) catch |build_err| {
                                if (shouldRetryWindowsCodexBuild(build_err, candidate.kind)) |retryable_err| {
                                    last_retryable_build_error = retryable_err;
                                    continue :candidate_loop;
                                }
                                writeCodexLoginLaunchFailureHint(@errorName(build_err)) catch {};
                                return build_err;
                            };
                            continue :spawn_attempt;
                        }

                        launch.deinit(std.heap.page_allocator);
                        if (shouldRetryWindowsCodexLaunch(err, candidate.kind)) {
                            last_retryable_spawn_error = err;
                            continue :candidate_loop;
                        }
                        writeCodexLoginLaunchFailureHint(@errorName(err)) catch {};
                        return err;
                    };
                }
            };
            launch.deinit(std.heap.page_allocator);

            const term = child.wait(app_runtime.io()) catch |err| {
                writeCodexLoginLaunchFailureHint(@errorName(err)) catch {};
                return err;
            };
            return ensureCodexLoginSucceeded(term);
        }

        const failure = finalRetryableWindowsCodexLaunchFailure(
            last_retryable_spawn_error,
            last_retryable_build_error,
        ) orelse unreachable;
        writeCodexLoginLaunchFailureHint(failure.hint_name) catch {};
        return failure.err;
    }

    var launch = buildCodexLaunchAlloc(std.heap.page_allocator, opts) catch |err| {
        writeCodexLoginLaunchFailureHint(@errorName(err)) catch {};
        return err;
    };
    defer launch.deinit(std.heap.page_allocator);

    var child = std.process.spawn(app_runtime.io(), .{
        .argv = launch.argv(),
        .environ_map = &env_map,
        .stdin = .inherit,
        .stdout = .inherit,
        .stderr = .inherit,
    }) catch |err| {
        writeCodexLoginLaunchFailureHint(@errorName(err)) catch {};
        return err;
    };
    const term = child.wait(app_runtime.io()) catch |err| {
        writeCodexLoginLaunchFailureHint(@errorName(err)) catch {};
        return err;
    };
    try ensureCodexLoginSucceeded(term);
}

/// Device authorization details captured from the `codex login --device-auth`
/// child output. The CLI owns this parsing; the capture tolerates ANSI color
/// codes and accepts any `https://auth.openai.com/…` URL plus a `XXXX-XXXX`
/// shaped code line.
pub const DeviceAuthInfo = struct {
    verification_url: []u8,
    user_code: []u8,

    pub fn deinit(self: *DeviceAuthInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.verification_url);
        allocator.free(self.user_code);
        self.* = undefined;
    }
};

/// A `codex login` child spawned with piped stdout for the JSON login flow.
/// The caller reads lines until the device info is captured, prints the
/// awaiting-user document, then calls `finish` to drain and wait.
pub const CapturedCodexLogin = struct {
    child: std.process.Child,
    stdout_file: std.Io.File,
    pending: std.ArrayList(u8),

    pub fn init(child: std.process.Child) CapturedCodexLogin {
        return .{
            .child = child,
            .stdout_file = child.stdout.?,
            .pending = std.ArrayList(u8).empty,
        };
    }

    pub fn deinit(self: *CapturedCodexLogin, allocator: std.mem.Allocator) void {
        self.pending.deinit(allocator);
        self.* = undefined;
    }

    /// Kill the child without waiting; used when the flow is abandoned.
    pub fn abandon(self: *CapturedCodexLogin) void {
        self.child.kill(app_runtime.io());
    }

    /// Read one child stdout line (without the newline). Returns null at EOF.
    /// Bytes past the last newline stay buffered in `pending`.
    pub fn readLine(self: *CapturedCodexLogin, allocator: std.mem.Allocator) !?[]u8 {
        var chunk: [256]u8 = undefined;
        while (true) {
            if (std.mem.indexOfScalar(u8, self.pending.items, '\n')) |pos| {
                const line = try allocator.dupe(u8, self.pending.items[0..pos]);
                std.mem.copyForwards(u8, self.pending.items, self.pending.items[pos + 1 ..]);
                self.pending.items.len -= pos + 1;
                return line;
            }
            const n = self.stdout_file.readStreaming(app_runtime.io(), &.{&chunk}) catch |err| switch (err) {
                error.EndOfStream => 0,
                else => return err,
            };
            if (n == 0) {
                if (self.pending.items.len == 0) return null;
                return try self.pending.toOwnedSlice(allocator);
            }
            try self.pending.appendSlice(allocator, chunk[0..n]);
        }
    }

    /// Drain remaining child stdout and wait for termination. `wait` closes
    /// the piped stdout handle, so the caller must not close it again.
    pub fn finish(self: *CapturedCodexLogin, allocator: std.mem.Allocator) !std.process.Child.Term {
        while (try self.readLine(allocator)) |line| allocator.free(line);
        return self.child.wait(app_runtime.io());
    }
};

pub fn spawnCodexLoginCapture(
    allocator: std.mem.Allocator,
    opts: types.LoginOptions,
    codex_home: []const u8,
) !CapturedCodexLogin {
    var env_map = try app_runtime.currentEnviron().createMap(allocator);
    defer env_map.deinit();
    try env_map.put("CODEX_HOME", codex_home);

    var launch = try buildCodexLaunchAlloc(allocator, opts);
    defer launch.deinit(allocator);

    const child = try std.process.spawn(app_runtime.io(), .{
        .argv = launch.argv(),
        .environ_map = &env_map,
        .stdin = .inherit,
        .stdout = .pipe,
        .stderr = .inherit,
    });
    return CapturedCodexLogin.init(child);
}

/// Read child stdout until both the verification URL and the user code are
/// captured. Returns null at EOF when either is missing.
pub fn captureDeviceAuthInfo(
    allocator: std.mem.Allocator,
    captured: *CapturedCodexLogin,
) !?DeviceAuthInfo {
    var url: ?[]u8 = null;
    var code: ?[]u8 = null;
    errdefer {
        if (url) |value| allocator.free(value);
        if (code) |value| allocator.free(value);
    }

    while (try captured.readLine(allocator)) |raw_line| {
        defer allocator.free(raw_line);
        const cleaned = try stripAnsiAlloc(allocator, raw_line);
        defer allocator.free(cleaned);
        const line = std.mem.trim(u8, cleaned, " \t\r");
        if (url == null) {
            if (extractVerificationUrl(line)) |start| {
                url = try allocator.dupe(u8, line[start..]);
            }
        } else if (code == null and isDeviceCodeShape(line)) {
            code = try allocator.dupe(u8, line);
        }
        if (url != null and code != null) break;
    }

    if (url == null or code == null) return null;
    return .{ .verification_url = url.?, .user_code = code.? };
}

fn stripAnsiAlloc(allocator: std.mem.Allocator, line: []const u8) ![]u8 {
    var out = std.ArrayList(u8).empty;
    errdefer out.deinit(allocator);
    var i: usize = 0;
    while (i < line.len) {
        if (line[i] == 0x1b and i + 1 < line.len and line[i + 1] == '[') {
            i += 2;
            while (i < line.len and line[i] != 'm') i += 1;
            if (i < line.len) i += 1;
            continue;
        }
        try out.append(allocator, line[i]);
        i += 1;
    }
    return try out.toOwnedSlice(allocator);
}

/// Returns the byte offset of an embedded `https://auth.openai.com/…` URL
/// within the line, or null. The URL may sit at the start of the line (the
/// shape codex 0.147.0 prints) or inside explanatory text; the marker itself
/// starts with `https://`, so the offset is the URL start.
fn extractVerificationUrl(line: []const u8) ?usize {
    return std.mem.indexOf(u8, line, "https://auth.openai.com");
}

fn isDeviceCodeShape(line: []const u8) bool {
    const dash = std.mem.indexOfScalar(u8, line, '-') orelse return false;
    if (dash < 3 or dash > 8) return false;
    const tail_len = line.len - dash - 1;
    if (tail_len < 3 or tail_len > 8) return false;
    for (line, 0..) |ch, idx| {
        if (idx == dash) continue;
        if (!std.ascii.isAlphanumeric(ch)) return false;
    }
    return true;
}
