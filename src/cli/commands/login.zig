const std = @import("std");
const types = @import("../types.zig");
const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 1 and common.isHelpFlag(std.mem.sliceTo(args[0], 0))) {
        return .{ .command = .{ .help = .login } };
    }

    const json_requested = common.argsContainFlag(args, "--json");
    var opts: types.LoginOptions = .{};
    var json_count: usize = 0;
    for (args) |raw_arg| {
        const arg = std.mem.sliceTo(raw_arg, 0);
        if (std.mem.eql(u8, arg, "--device-auth")) {
            if (opts.device_auth) return common.usageErrorResultWithJson(allocator, .login, json_requested, "duplicate `--device-auth` for `login`.", .{});
            opts.device_auth = true;
            continue;
        }
        if (std.mem.eql(u8, arg, "--json")) {
            json_count += 1;
            continue;
        }
        if (common.isHelpFlag(arg)) return common.usageErrorResultWithJson(allocator, .login, json_requested, "`--help` must be used by itself for `login`.", .{});
        if (std.mem.startsWith(u8, arg, "-")) return common.usageErrorResultWithJson(allocator, .login, json_requested, "unknown flag `{s}` for `login`.", .{arg});
        return common.usageErrorResultWithJson(allocator, .login, json_requested, "unexpected argument `{s}` for `login`.", .{arg});
    }
    if (json_count > 1) return common.usageErrorResultWithJson(allocator, .login, true, "duplicate `--json` for `login`.", .{});
    if (json_requested and !opts.device_auth) {
        return common.usageErrorResultWithJson(allocator, .login, true, "`login --json` requires `--device-auth`.", .{});
    }
    opts.json = json_requested;
    return .{ .command = .{ .login = opts } };
}
