const std = @import("std");
const types = @import("../types.zig");
const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 0) return parseOptions(allocator, .launch, args);
    const first = std.mem.sliceTo(args[0], 0);
    if (common.isHelpFlag(first)) return .{ .command = .{ .help = .app } };

    return parseOptions(allocator, .launch, args);
}

fn parseOptions(
    allocator: std.mem.Allocator,
    action: types.AppAction,
    args: []const [:0]const u8,
) !types.ParseResult {
    const json_requested = common.argsContainFlag(args, "--json");
    var opts = types.AppOptions{ .action = action };
    var json_count: usize = 0;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = std.mem.sliceTo(args[i], 0);
        if (std.mem.eql(u8, arg, "--")) return common.usageErrorResultWithJson(allocator, .app, json_requested, "`app` does not accept passthrough arguments.", .{});
        if (common.isHelpFlag(arg)) return .{ .command = .{ .help = .app } };
        if (std.mem.eql(u8, arg, "--id")) {
            if (i + 1 >= args.len) return common.usageErrorResultWithJson(allocator, .app, json_requested, "missing value for `--id`.", .{});
            if (opts.app_id != null) return common.usageErrorResultWithJson(allocator, .app, json_requested, "duplicate `--id` for `app`.", .{});
            i += 1;
            opts.app_id = std.mem.sliceTo(args[i], 0);
            continue;
        }
        if (std.mem.eql(u8, arg, "--codex-cli-path")) {
            if (i + 1 >= args.len) return common.usageErrorResultWithJson(allocator, .app, json_requested, "missing value for `--codex-cli-path`.", .{});
            if (opts.codex_cli_path != null) return common.usageErrorResultWithJson(allocator, .app, json_requested, "duplicate `--codex-cli-path` for `app`.", .{});
            i += 1;
            opts.codex_cli_path = std.mem.sliceTo(args[i], 0);
            continue;
        }
        if (std.mem.eql(u8, arg, "--codex-home")) {
            if (i + 1 >= args.len) return common.usageErrorResultWithJson(allocator, .app, json_requested, "missing value for `--codex-home`.", .{});
            if (opts.codex_home != null) return common.usageErrorResultWithJson(allocator, .app, json_requested, "duplicate `--codex-home` for `app`.", .{});
            i += 1;
            opts.codex_home = std.mem.sliceTo(args[i], 0);
            continue;
        }
        if (std.mem.eql(u8, arg, "--platform")) {
            if (i + 1 >= args.len) return common.usageErrorResultWithJson(allocator, .app, json_requested, "missing value for `--platform`.", .{});
            if (opts.platform != null) return common.usageErrorResultWithJson(allocator, .app, json_requested, "duplicate `--platform` for `app`.", .{});
            i += 1;
            const value = std.mem.sliceTo(args[i], 0);
            if (std.mem.eql(u8, value, "win")) {
                opts.platform = .win;
            } else if (std.mem.eql(u8, value, "wsl")) {
                opts.platform = .wsl;
            } else if (std.mem.eql(u8, value, "mac")) {
                opts.platform = .mac;
            } else {
                return common.usageErrorResultWithJson(allocator, .app, json_requested, "`--platform` must be `win`, `wsl`, or `mac`.", .{});
            }
            continue;
        }
        if (std.mem.eql(u8, arg, "--json")) {
            json_count += 1;
            continue;
        }
        if (std.mem.eql(u8, arg, "--std")) {
            if (opts.inherit_stdio) return common.usageErrorResultWithJson(allocator, .app, json_requested, "duplicate `--std` for `app`.", .{});
            opts.inherit_stdio = true;
            continue;
        }
        if (std.mem.startsWith(u8, arg, "-")) {
            return common.usageErrorResultWithJson(allocator, .app, json_requested, "unknown flag `{s}` for `app`.", .{arg});
        }
        return common.usageErrorResultWithJson(allocator, .app, json_requested, "unexpected argument `{s}` for `app`.", .{arg});
    }
    if (json_count > 1) return common.usageErrorResultWithJson(allocator, .app, true, "duplicate `--json` for `app`.", .{});
    if (json_requested and opts.inherit_stdio) {
        return common.usageErrorResultWithJson(allocator, .app, true, "`--std` cannot be combined with `--json` for `app`.", .{});
    }
    opts.json = json_requested;

    return .{ .command = .{ .app = opts } };
}
