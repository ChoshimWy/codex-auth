const std = @import("std");
const cli = @import("../cli/root.zig");
const registry = @import("../registry/root.zig");
const io_util = @import("../core/io_util.zig");

pub fn handleExport(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.ExportOptions) !void {
    var reg = if (opts.json)
        registry.loadRegistry(allocator, codex_home) catch |err| return cli.json_output.printJsonWorkflowError(err)
    else
        try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);

    var summary = if (opts.json)
        registry.exportAccounts(allocator, codex_home, &reg, opts.dest_path, switch (opts.format) {
            .standard => .standard,
            .cpa => .cpa,
        }) catch |err| return printExportErrorJson(allocator, err)
    else
        try registry.exportAccounts(allocator, codex_home, &reg, opts.dest_path, switch (opts.format) {
            .standard => .standard,
            .cpa => .cpa,
        });
    defer summary.deinit(allocator);

    if (opts.json) {
        try cli.json_output.printExportResult(&summary, exportFormatName(opts.format));
        return;
    }

    var stdout: io_util.Stdout = undefined;
    stdout.init();
    const out = stdout.out();
    try out.print("Exported {d} {s} to {s}\n", .{
        summary.exported,
        if (summary.exported == 1) "account" else "accounts",
        summary.dest_path,
    });
    try out.flush();
}

fn exportFormatName(format: cli.types.ExportFormat) []const u8 {
    return switch (format) {
        .standard => "standard",
        .cpa => "cpa",
    };
}

fn printExportErrorJson(allocator: std.mem.Allocator, failure: anyerror) anyerror {
    if (failure == error.OutOfMemory) return failure;
    const message = try std.fmt.allocPrint(allocator, "export could not be written: {s}", .{@errorName(failure)});
    defer allocator.free(message);
    try cli.json_output.printError("path_not_writable", message, null);
    return error.ExportFailed;
}
