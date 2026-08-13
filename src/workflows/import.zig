const std = @import("std");
const cli = @import("../cli/root.zig");
const registry = @import("../registry/root.zig");
const account_names = @import("account_names.zig");

const loadSingleFileImportAuthInfo = account_names.loadSingleFileImportAuthInfo;
const refreshAccountNamesAfterImport = account_names.refreshAccountNamesAfterImport;
const defaultAccountFetcher = account_names.defaultAccountFetcher;

pub fn handleImport(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.ImportOptions) !void {
    if (opts.json) return handleImportJson(allocator, codex_home, opts);

    if (opts.purge) {
        var report = try registry.purgeRegistryFromImportSource(allocator, codex_home, opts.auth_path, opts.alias);
        defer report.deinit(allocator);
        try cli.output.printImportReport(&report);
        if (report.failure != null) return error.ImportFailed;
        return;
    }

    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);
    var report = switch (opts.source) {
        .standard => try registry.importAuthPath(allocator, codex_home, &reg, opts.auth_path.?, opts.alias),
        .cpa => try registry.importCpaPath(allocator, codex_home, &reg, opts.auth_path, opts.alias),
    };
    defer report.deinit(allocator);
    if (report.appliedCount() > 0) {
        if (report.render_kind == .single_file) {
            var imported_info = try loadSingleFileImportAuthInfo(allocator, opts);
            defer if (imported_info) |*info| info.deinit(allocator);
            _ = try refreshAccountNamesAfterImport(
                allocator,
                &reg,
                opts.purge,
                report.render_kind,
                if (imported_info) |*info| info else null,
                defaultAccountFetcher,
            );
        }
        try registry.saveRegistry(allocator, codex_home, &reg);
    }
    try cli.output.printImportReport(&report);
    if (report.failure != null) return error.ImportFailed;
}

const import_json_uncertain_message =
    "the import operation could not be completed; stored state may have changed; run `list --json` before retrying";

fn handleImportJson(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.ImportOptions) !void {
    if (opts.purge) {
        var report = registry.purgeRegistryFromImportSource(allocator, codex_home, opts.auth_path, opts.alias) catch |err|
            return printImportErrorJson(allocator, err);
        defer report.deinit(allocator);
        if (report.failure) |failure| return printImportErrorJson(allocator, failure);

        var reg_after = registry.loadRegistry(allocator, codex_home) catch |err|
            return cli.json_output.printJsonWorkflowError(err);
        defer reg_after.deinit(allocator);
        try cli.json_output.printImportResult(&report, "purge", report.source_label, reg_after.active_account_key, true);
        return;
    }

    var reg = registry.loadRegistry(allocator, codex_home) catch |err|
        return cli.json_output.printJsonWorkflowError(err);
    defer reg.deinit(allocator);
    var report = switch (opts.source) {
        .standard => registry.importAuthPath(allocator, codex_home, &reg, opts.auth_path.?, opts.alias) catch |err|
            return printImportErrorJson(allocator, err),
        .cpa => registry.importCpaPath(allocator, codex_home, &reg, opts.auth_path, opts.alias) catch |err|
            return printImportErrorJson(allocator, err),
    };
    defer report.deinit(allocator);
    if (report.failure) |failure| return printImportErrorJson(allocator, failure);

    if (report.appliedCount() > 0) {
        if (report.render_kind == .single_file) {
            var imported_info = loadSingleFileImportAuthInfo(allocator, opts) catch |err|
                return cli.json_output.printJsonWorkflowError(err);
            defer if (imported_info) |*info| info.deinit(allocator);
            _ = refreshAccountNamesAfterImport(
                allocator,
                &reg,
                opts.purge,
                report.render_kind,
                if (imported_info) |*info| info else null,
                defaultAccountFetcher,
            ) catch |err| return cli.json_output.printJsonWorkflowError(err);
        }
        registry.saveRegistry(allocator, codex_home, &reg) catch |err|
            return cli.json_output.printJsonMutationError(err, import_json_uncertain_message);
    }
    try cli.json_output.printImportResult(&report, importJsonModeName(opts), importJsonSourceLabel(opts), reg.active_account_key, null);
}

fn printImportErrorJson(allocator: std.mem.Allocator, failure: anyerror) anyerror {
    if (failure == error.OutOfMemory) return failure;
    if (registry.import_helpers.isImportSourceFileError(failure)) {
        const message = try std.fmt.allocPrint(allocator, "import source could not be read: {s}", .{@errorName(failure)});
        defer allocator.free(message);
        try cli.json_output.printError("path_unreadable", message, null);
        return error.ImportFailed;
    }
    return cli.json_output.printJsonWorkflowError(failure);
}

fn importJsonModeName(opts: cli.types.ImportOptions) []const u8 {
    if (opts.purge) return "purge";
    return switch (opts.source) {
        .standard => "standard",
        .cpa => "cpa",
    };
}

fn importJsonSourceLabel(opts: cli.types.ImportOptions) ?[]const u8 {
    if (opts.auth_path) |path| return path;
    return if (opts.source == .cpa) "~/.cli-proxy-api" else null;
}
