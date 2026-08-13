const std = @import("std");
const types = @import("../types.zig");
const common = @import("common.zig");

pub fn parse(allocator: std.mem.Allocator, args: []const [:0]const u8) !types.ParseResult {
    if (args.len == 1 and common.isHelpFlag(std.mem.sliceTo(args[0], 0))) {
        return .{ .command = .{ .help = .export_auth } };
    }

    const json_requested = common.argsContainFlag(args, "--json");
    var dest_path: ?[]u8 = null;
    var format: types.ExportFormat = .standard;
    var json_count: usize = 0;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        const arg = std.mem.sliceTo(args[i], 0);
        if (std.mem.eql(u8, arg, "--cpa")) {
            if (format == .cpa) {
                if (dest_path) |path| allocator.free(path);
                return common.usageErrorResultWithJson(allocator, .export_auth, json_requested, "duplicate `--cpa` for `export`.", .{});
            }
            format = .cpa;
        } else if (std.mem.eql(u8, arg, "--json")) {
            json_count += 1;
        } else if (common.isHelpFlag(arg)) {
            if (dest_path) |path| allocator.free(path);
            return common.usageErrorResultWithJson(allocator, .export_auth, json_requested, "`--help` must be used by itself for `export`.", .{});
        } else if (std.mem.startsWith(u8, arg, "-")) {
            if (dest_path) |path| allocator.free(path);
            return common.usageErrorResultWithJson(allocator, .export_auth, json_requested, "unknown flag `{s}` for `export`.", .{arg});
        } else {
            if (dest_path != null) {
                if (dest_path) |path| allocator.free(path);
                return common.usageErrorResultWithJson(allocator, .export_auth, json_requested, "unexpected extra path `{s}` for `export`.", .{arg});
            }
            dest_path = try allocator.dupe(u8, arg);
        }
    }
    if (json_count > 1) {
        if (dest_path) |path| allocator.free(path);
        return common.usageErrorResultWithJson(allocator, .export_auth, true, "duplicate `--json` for `export`.", .{});
    }

    return .{ .command = .{ .export_auth = .{
        .dest_path = dest_path,
        .format = format,
        .json = json_requested,
    } } };
}
