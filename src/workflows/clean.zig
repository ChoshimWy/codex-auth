const std = @import("std");
const app_runtime = @import("../core/runtime.zig");
const cli = @import("../cli/root.zig");
const registry = @import("../registry/root.zig");
const legacy_background = @import("legacy_background.zig");

pub fn handleClean(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.CleanOptions) !void {
    if (opts.json) return handleCleanJson(allocator, codex_home, opts);

    var stdout: [256]u8 = undefined;
    var writer = std.Io.File.stdout().writer(app_runtime.io(), &stdout);
    const out = &writer.interface;
    switch (opts.target) {
        .accounts => {
            const summary = try registry.cleanAccountsBackups(allocator, codex_home);
            try out.print(
                "cleaned accounts: auth_backups={d}, registry_backups={d}, stale_entries={d}\n",
                .{
                    summary.auth_backups_removed,
                    summary.registry_backups_removed,
                    summary.stale_snapshot_files_removed,
                },
            );
        },
        .background => {
            const summary = try legacy_background.clean(allocator);
            try out.print(
                "cleaned legacy background registrations: platform={s}, files_removed={d}\n",
                .{ summary.platform, summary.files_removed },
            );
        },
    }
    try out.flush();
}

fn handleCleanJson(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.CleanOptions) !void {
    switch (opts.target) {
        .accounts => {
            const summary = registry.cleanAccountsBackups(allocator, codex_home) catch |err|
                return cli.json_output.printJsonWorkflowError(err);
            var view = cli.json_output.CleanResultView{
                .target = "accounts",
                .auth_backups_removed = summary.auth_backups_removed,
                .registry_backups_removed = summary.registry_backups_removed,
                .stale_snapshot_files_removed = summary.stale_snapshot_files_removed,
            };
            try cli.json_output.printCleanResult(&view);
        },
        .background => {
            const summary = legacy_background.clean(allocator) catch |err|
                return cli.json_output.printJsonWorkflowError(err);
            var view = cli.json_output.CleanResultView{
                .target = "background",
                .platform = summary.platform,
                .files_removed = summary.files_removed,
            };
            try cli.json_output.printCleanResult(&view);
        },
    }
}
