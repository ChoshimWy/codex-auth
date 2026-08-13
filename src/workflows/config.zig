const std = @import("std");
const cli = @import("../cli/root.zig");
const io_util = @import("../core/io_util.zig");
const registry = @import("../registry/root.zig");

const config_json_uncertain_message =
    "the config operation could not be completed; stored state may have changed; run `list --json` before retrying";

pub fn handleConfig(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.ConfigOptions) !void {
    switch (opts) {
        .live => |live_opts| {
            if (live_opts.json) return handleLiveJson(allocator, codex_home, live_opts.interval_seconds);
            try handleLiveCommand(allocator, codex_home, live_opts);
        },
        .get => |get_opts| {
            _ = get_opts;
            try handleGetJson(allocator, codex_home);
        },
    }
}

fn handleLiveCommand(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.LiveOptions) !void {
    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    reg.live.interval_seconds = opts.interval_seconds;
    try registry.saveRegistry(allocator, codex_home, &reg);

    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try out.print("Live refresh interval: {d}s\n", .{opts.interval_seconds});
    try out.flush();
}

fn handleLiveJson(allocator: std.mem.Allocator, codex_home: []const u8, interval_seconds: u16) !void {
    var reg = registry.loadRegistry(allocator, codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer reg.deinit(allocator);
    reg.live.interval_seconds = interval_seconds;
    registry.saveRegistry(allocator, codex_home, &reg) catch |err|
        return cli.json_output.printJsonMutationError(err, config_json_uncertain_message);
    try cli.json_output.printConfigResult("live", reg.live.interval_seconds);
}

fn handleGetJson(allocator: std.mem.Allocator, codex_home: []const u8) !void {
    var reg = registry.loadRegistry(allocator, codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer reg.deinit(allocator);
    try cli.json_output.printConfigResult("live", reg.live.interval_seconds);
}
