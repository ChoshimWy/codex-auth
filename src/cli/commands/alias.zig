const std = @import("std");
const types = @import("../types.zig");
const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 1 and common.isHelpFlag(std.mem.sliceTo(args[0], 0))) {
        return .{ .command = .{ .help = .alias } };
    }
    if (args.len == 0) {
        return common.usageErrorResult(allocator, .alias, "`alias` requires `set` or `clear`.", .{});
    }

    const subcommand = std.mem.sliceTo(args[0], 0);
    const json_requested = common.argsContainFlag(args[1..], "--json");
    if (std.mem.eql(u8, subcommand, "set")) return parseSet(allocator, args[1..], json_requested);
    if (std.mem.eql(u8, subcommand, "clear")) return parseClear(allocator, args[1..], json_requested);
    if (common.isHelpFlag(subcommand)) {
        return common.usageErrorResult(allocator, .alias, "`--help` must be used by itself for `alias`.", .{});
    }
    if (std.mem.startsWith(u8, subcommand, "-")) {
        return common.usageErrorResult(allocator, .alias, "unknown flag `{s}` for `alias`.", .{subcommand});
    }
    return common.usageErrorResult(allocator, .alias, "unknown alias subcommand `{s}`.", .{subcommand});
}

fn parseSet(
    allocator: std.mem.Allocator,
    args: []const [:0]const u8,
    json_requested: bool,
) !types.ParseResult {
    var positional: [3][:0]const u8 = undefined;
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
    if (json_count > 1) return common.usageErrorResultWithJson(allocator, .alias, true, "duplicate `--json` for `alias`.", .{});
    if (positional_len < 2) return common.usageErrorResultWithJson(allocator, .alias, json_requested, "`alias set` requires a selector and alias.", .{});
    if (positional_len > 2) return common.usageErrorResultWithJson(allocator, .alias, json_requested, "unexpected extra argument `{s}` for `alias set`.", .{std.mem.sliceTo(positional[2], 0)});

    const selector = try allocator.dupe(u8, std.mem.sliceTo(positional[0], 0));
    errdefer allocator.free(selector);
    const alias_value = try allocator.dupe(u8, std.mem.sliceTo(positional[1], 0));
    return .{ .command = .{ .alias = .{ .set = .{
        .selector = selector,
        .alias = alias_value,
        .json = json_requested,
    } } } };
}

fn parseClear(
    allocator: std.mem.Allocator,
    args: []const [:0]const u8,
    json_requested: bool,
) !types.ParseResult {
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
    if (json_count > 1) return common.usageErrorResultWithJson(allocator, .alias, true, "duplicate `--json` for `alias`.", .{});
    if (positional_len < 1) return common.usageErrorResultWithJson(allocator, .alias, json_requested, "`alias clear` requires a selector.", .{});
    if (positional_len > 1) return common.usageErrorResultWithJson(allocator, .alias, json_requested, "unexpected extra argument `{s}` for `alias clear`.", .{std.mem.sliceTo(positional[1], 0)});

    return .{ .command = .{ .alias = .{ .clear = .{
        .selector = try allocator.dupe(u8, std.mem.sliceTo(positional[0], 0)),
        .json = json_requested,
    } } } };
}
