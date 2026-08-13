const std = @import("std");
const cli = @import("../cli/root.zig");
const registry = @import("../registry/root.zig");
const query_mod = @import("query.zig");
const results = @import("results.zig");

pub fn handleAlias(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.AliasOptions) !void {
    const wants_json = switch (opts) {
        .set => |set_opts| set_opts.json,
        .clear => |clear_opts| clear_opts.json,
    };
    if (wants_json) return handleAliasJson(allocator, codex_home, opts);

    var reg = try registry.loadRegistry(allocator, codex_home);
    defer reg.deinit(allocator);

    switch (opts) {
        .set => |set_opts| {
            const idx = (try resolveAliasTargetIndex(allocator, &reg, set_opts.selector)) orelse return;
            try validateAlias(allocator, &reg, set_opts.alias, idx);
            const old_alias = try allocator.dupe(u8, reg.accounts.items[idx].alias);
            defer allocator.free(old_alias);
            try replaceAlias(allocator, &reg.accounts.items[idx], set_opts.alias);
            try registry.saveRegistry(allocator, codex_home, &reg);
            try cli.output.printAliasSet(&reg.accounts.items[idx], old_alias);
        },
        .clear => |clear_opts| {
            const idx = (try resolveAliasTargetIndex(allocator, &reg, clear_opts.selector)) orelse return;
            const old_alias = try allocator.dupe(u8, reg.accounts.items[idx].alias);
            defer allocator.free(old_alias);
            try replaceAlias(allocator, &reg.accounts.items[idx], "");
            try registry.saveRegistry(allocator, codex_home, &reg);
            try cli.output.printAliasCleared(&reg.accounts.items[idx], old_alias);
        },
    }
}

const alias_json_uncertain_message =
    "the alias operation could not be completed; stored state may have changed; run `list --json` before retrying";

pub fn handleAliasJson(allocator: std.mem.Allocator, codex_home: []const u8, opts: cli.types.AliasOptions) !void {
    var reg = registry.loadRegistry(allocator, codex_home) catch |err| return cli.json_output.printJsonWorkflowError(err);
    defer reg.deinit(allocator);

    switch (opts) {
        .set => |set_opts| {
            const idx = (try resolveAliasTargetIndexJson(allocator, &reg, set_opts.selector)) orelse return;
            if (try checkAlias(allocator, &reg, set_opts.alias, idx)) |failure| {
                defer allocator.free(failure.message);
                try cli.json_output.printError(failure.code, failure.message, null);
                return if (std.mem.eql(u8, failure.code, "duplicate_alias")) error.DuplicateAlias else error.InvalidAlias;
            }
            try replaceAlias(allocator, &reg.accounts.items[idx], set_opts.alias);
            registry.saveRegistry(allocator, codex_home, &reg) catch |err|
                return cli.json_output.printJsonMutationError(err, alias_json_uncertain_message);
            var result = results.buildAliasResult(allocator, &reg, reg.accounts.items[idx].account_key) catch |err|
                return cli.json_output.printJsonWorkflowError(err);
            defer result.deinit(allocator);
            try cli.json_output.printAliasResult(&result, "set");
        },
        .clear => |clear_opts| {
            const idx = (try resolveAliasTargetIndexJson(allocator, &reg, clear_opts.selector)) orelse return;
            try replaceAlias(allocator, &reg.accounts.items[idx], "");
            registry.saveRegistry(allocator, codex_home, &reg) catch |err|
                return cli.json_output.printJsonMutationError(err, alias_json_uncertain_message);
            var result = results.buildAliasResult(allocator, &reg, reg.accounts.items[idx].account_key) catch |err|
                return cli.json_output.printJsonWorkflowError(err);
            defer result.deinit(allocator);
            try cli.json_output.printAliasResult(&result, "clear");
        },
    }
}

fn resolveAliasTargetIndexJson(
    allocator: std.mem.Allocator,
    reg: *registry.Registry,
    selector: []const u8,
) !?usize {
    var resolution = try query_mod.resolveSwitchQueryLocally(allocator, reg, selector);
    defer resolution.deinit(allocator);

    const account_key = switch (resolution) {
        .not_found => {
            const message = try std.fmt.allocPrint(allocator, "no account matches \"{s}\"", .{selector});
            defer allocator.free(message);
            try cli.json_output.printError("account_not_found", message, null);
            return error.AccountNotFound;
        },
        .direct => |key| key,
        .multiple => |matches| {
            const candidates = try results.buildAccountViewsForIndices(allocator, reg, null, matches.items);
            defer results.deinitAccountViews(allocator, candidates);
            const message = try std.fmt.allocPrint(allocator, "query \"{s}\" matches multiple accounts", .{selector});
            defer allocator.free(message);
            try cli.json_output.printError("ambiguous_query", message, candidates);
            return error.AmbiguousQuery;
        },
    };
    return registry.findAccountIndexByAccountKey(reg, account_key) orelse error.AccountNotFound;
}

fn resolveAliasTargetIndex(
    allocator: std.mem.Allocator,
    reg: *registry.Registry,
    selector: []const u8,
) !?usize {
    var resolution = try query_mod.resolveSwitchQueryLocally(allocator, reg, selector);
    defer resolution.deinit(allocator);

    const account_key = switch (resolution) {
        .not_found => {
            try cli.output.printAliasAccountNotFoundError(selector);
            return error.AccountNotFound;
        },
        .direct => |key| key,
        .multiple => |matches| blk: {
            const selected_account_key = cli.picker.selectAccountFromIndicesWithUsageOverrides(
                allocator,
                reg,
                matches.items,
                null,
            ) catch |err| {
                if (err == error.TuiRequiresTty) {
                    try cli.output.printAliasRequiresTtyError();
                    return error.AliasSelectionRequiresTty;
                }
                return err;
            };
            if (selected_account_key == null) return null;
            break :blk selected_account_key.?;
        },
    };
    return registry.findAccountIndexByAccountKey(reg, account_key) orelse error.AccountNotFound;
}

fn replaceAlias(allocator: std.mem.Allocator, rec: *registry.AccountRecord, alias_value: []const u8) !void {
    const owned_alias = try allocator.dupe(u8, alias_value);
    allocator.free(rec.alias);
    rec.alias = owned_alias;
}

const AliasFailure = struct {
    code: []const u8,
    message: []u8,
};

fn checkAlias(
    allocator: std.mem.Allocator,
    reg: *registry.Registry,
    alias_value: []const u8,
    selected_idx: usize,
) !?AliasFailure {
    if (alias_value.len == 0) {
        return .{
            .code = "invalid_alias",
            .message = try allocator.dupe(u8, "alias cannot be empty; use `codex-auth alias clear <selector>` to remove one."),
        };
    }
    if (query_mod.parseDisplayNumber(alias_value) != null) {
        return .{
            .code = "invalid_alias",
            .message = try allocator.dupe(u8, "alias cannot be only digits because numbers select displayed rows."),
        };
    }
    for (alias_value) |ch| {
        if (ch < 0x20 or ch == 0x7f) {
            return .{
                .code = "invalid_alias",
                .message = try allocator.dupe(u8, "alias cannot contain control characters."),
            };
        }
    }
    if (aliasOwnerEmail(reg, alias_value, selected_idx)) |email| {
        return .{
            .code = "duplicate_alias",
            .message = try std.fmt.allocPrint(allocator, "alias '{s}' is already used by {s}.", .{ alias_value, email }),
        };
    }
    return null;
}

fn aliasOwnerEmail(reg: *registry.Registry, alias_value: []const u8, selected_idx: usize) ?[]const u8 {
    for (reg.accounts.items, 0..) |rec, idx| {
        if (idx == selected_idx) continue;
        if (rec.alias.len != 0 and std.ascii.eqlIgnoreCase(rec.alias, alias_value)) return rec.email;
    }
    return null;
}

fn validateAlias(allocator: std.mem.Allocator, reg: *registry.Registry, alias_value: []const u8, selected_idx: usize) !void {
    const failure = (try checkAlias(allocator, reg, alias_value, selected_idx)) orelse return;
    defer allocator.free(failure.message);
    if (std.mem.eql(u8, failure.code, "duplicate_alias")) {
        const email = aliasOwnerEmail(reg, alias_value, selected_idx).?;
        try cli.output.printDuplicateAliasError(alias_value, email);
        return error.DuplicateAlias;
    }
    try cli.output.printInvalidAliasError(failure.message);
    return error.InvalidAlias;
}
