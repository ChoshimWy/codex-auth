const std = @import("std");
const types = @import("../types.zig");
const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 1 and common.isHelpFlag(std.mem.sliceTo(args[0], 0))) {
        return .{ .command = .{ .help = .config } };
    }
    if (args.len < 1) return common.usageErrorResult(allocator, .config, "`config` requires a section.", .{});
    const scope = std.mem.sliceTo(args[0], 0);

    if (std.mem.eql(u8, scope, "live")) {
        return parseLive(allocator, args[1..]);
    }
    if (std.mem.eql(u8, scope, "get")) {
        return parseGet(allocator, args[1..]);
    }
    return common.usageErrorResult(allocator, .config, "unknown config section `{s}`.", .{scope});
}

fn parseGet(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 1 and common.isHelpFlag(std.mem.sliceTo(args[0], 0))) {
        return .{ .command = .{ .help = .config } };
    }
    const json_requested = common.argsContainFlag(args, "--json");
    var json_count: usize = 0;
    for (args) |raw_arg| {
        const arg = std.mem.sliceTo(raw_arg, 0);
        if (std.mem.eql(u8, arg, "--json")) {
            json_count += 1;
            continue;
        }
        return common.usageErrorResultWithJson(allocator, .config, json_requested, "unexpected argument `{s}` for `config get`.", .{arg});
    }
    if (json_count > 1) return common.usageErrorResultWithJson(allocator, .config, true, "duplicate `--json` for `config get`.", .{});
    if (json_count == 0) return common.usageErrorResult(allocator, .config, "`config get` requires `--json`.", .{});
    return .{ .command = .{ .config = .{ .get = .{ .json = true } } } };
}

fn parseLive(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 1 and common.isHelpFlag(std.mem.sliceTo(args[0], 0))) {
        return .{ .command = .{ .help = .config } };
    }
    const json_requested = common.argsContainFlag(args, "--json");
    var positional: [2][:0]const u8 = undefined;
    var positional_len: usize = 0;
    var json_count: usize = 0;
    for (args) |raw_arg| {
        const arg = std.mem.sliceTo(raw_arg, 0);
        if (std.mem.eql(u8, arg, "--json")) {
            json_count += 1;
            continue;
        }
        if (positional_len < positional.len) positional[positional_len] = raw_arg;
        positional_len += 1;
    }
    if (json_count > 1) return common.usageErrorResultWithJson(allocator, .config, true, "duplicate `--json` for `config live`.", .{});
    if (positional_len != 2) return common.usageErrorResultWithJson(allocator, .config, json_requested, "`config live` requires `--interval <seconds>`.", .{});
    const flag = std.mem.sliceTo(positional[0], 0);
    if (!std.mem.eql(u8, flag, "--interval")) {
        if (std.mem.startsWith(u8, flag, "-")) {
            return common.usageErrorResultWithJson(allocator, .config, json_requested, "unknown flag `{s}` for `config live`.", .{flag});
        }
        return common.usageErrorResultWithJson(allocator, .config, json_requested, "unknown argument `{s}` for `config live`.", .{flag});
    }
    const raw = std.mem.sliceTo(positional[1], 0);
    const interval = std.fmt.parseInt(u16, raw, 10) catch
        return common.usageErrorResultWithJson(allocator, .config, json_requested, "`--interval` must be an integer from 5 to 3600 seconds.", .{});
    if (interval < 5 or interval > 3600) {
        return common.usageErrorResultWithJson(allocator, .config, json_requested, "`--interval` must be an integer from 5 to 3600 seconds.", .{});
    }
    return .{ .command = .{ .config = .{ .live = .{ .interval_seconds = interval, .json = json_requested } } } };
}
