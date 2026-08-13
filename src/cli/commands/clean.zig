const std = @import("std");
const types = @import("../types.zig");
const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    const json_requested = common.argsContainFlag(args, "--json");
    if (args.len == 0) return .{ .command = .{ .clean = .{ .json = json_requested } } };
    const first = std.mem.sliceTo(args[0], 0);
    if (args.len == 1 and common.isHelpFlag(first)) return .{ .command = .{ .help = .clean } };
    if (std.mem.eql(u8, first, "background")) {
        var json_count: usize = 0;
        for (args[1..]) |raw_arg| {
            const arg = std.mem.sliceTo(raw_arg, 0);
            if (std.mem.eql(u8, arg, "--json")) {
                json_count += 1;
                continue;
            }
            return common.usageErrorResultWithJson(allocator, .clean, json_requested, "unexpected argument after `clean background`: `{s}`.", .{arg});
        }
        if (json_count > 1) return common.usageErrorResultWithJson(allocator, .clean, true, "duplicate `--json` for `clean`.", .{});
        return .{ .command = .{ .clean = .{ .target = .background, .json = json_count == 1 } } };
    }
    if (std.mem.eql(u8, first, "--json")) {
        if (args.len == 1) return .{ .command = .{ .clean = .{ .json = true } } };
        return common.usageErrorResultWithJson(allocator, .clean, true, "duplicate `--json` for `clean`.", .{});
    }
    if (args.len > 1) {
        return common.usageErrorResultWithJson(allocator, .clean, json_requested, "unexpected argument after `clean`: `{s}`.", .{
            std.mem.sliceTo(args[1], 0),
        });
    }
    return common.usageErrorResultWithJson(allocator, .clean, json_requested, "unknown clean target `{s}`.", .{first});
}
