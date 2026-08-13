const std = @import("std");
const cli = @import("codex_auth").cli;
const registry = @import("codex_auth").registry;
const workflows = @import("codex_auth").workflows;

fn expectContains(text: []const u8, fragment: []const u8) !void {
    try std.testing.expect(std.mem.indexOf(u8, text, fragment) != null);
}

test "Scenario: Given --version --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "--version", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .version => |opts| try std.testing.expect(opts.json),
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given bare --version when parsing then json mode is off" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "--version" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .version => |opts| try std.testing.expect(!opts.json),
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given -V --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "-V", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .version => |opts| try std.testing.expect(opts.json),
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given an unknown argument after --version when parsing then usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "--version", "--bogus" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| try expectContains(usage_err.message, "unexpected argument after"),
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given --version with duplicate --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "--version", "--json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "duplicate `--json`");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given extra arguments after --version --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "--version", "--json", "extra" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "unexpected argument after");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given an alias value starting with a dash when parsing then it stays a positional value" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "work", "-x" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .alias => |opts| switch (opts) {
                .set => |set_opts| {
                    try std.testing.expect(!set_opts.json);
                    try std.testing.expectEqualStrings("work", set_opts.selector);
                    try std.testing.expectEqualStrings("-x", set_opts.alias);
                },
                .clear => return error.TestExpectedEqual,
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias set with --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "work", "prod", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .alias => |opts| switch (opts) {
                .set => |set_opts| {
                    try std.testing.expect(set_opts.json);
                    try std.testing.expectEqualStrings("work", set_opts.selector);
                    try std.testing.expectEqualStrings("prod", set_opts.alias);
                },
                .clear => return error.TestExpectedEqual,
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias set with --json in the middle when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "--json", "work", "prod" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .alias => |opts| switch (opts) {
                .set => |set_opts| try std.testing.expect(set_opts.json),
                .clear => return error.TestExpectedEqual,
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias set without --json when parsing then json mode is off" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "work", "prod" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .alias => |opts| switch (opts) {
                .set => |set_opts| try std.testing.expect(!set_opts.json),
                .clear => return error.TestExpectedEqual,
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias clear with --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "clear", "work", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .alias => |opts| switch (opts) {
                .set => return error.TestExpectedEqual,
                .clear => |clear_opts| {
                    try std.testing.expect(clear_opts.json);
                    try std.testing.expectEqualStrings("work", clear_opts.selector);
                },
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias set missing the alias with --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "work", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "`alias set` requires a selector and alias.");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias set with duplicate --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "work", "prod", "--json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "duplicate `--json`");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given alias set with an extra positional when parsing then usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "alias", "set", "a", "b", "c" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| try expectContains(usage_err.message, "unexpected extra argument"),
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given import with --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "import", "file.json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .import_auth => |opts| {
                try std.testing.expect(opts.json);
                try std.testing.expectEqualStrings("file.json", opts.auth_path.?);
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given import with --json and no path when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "import", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "`import` requires a path");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given import with an extra path and --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "import", "a.json", "b.json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "unexpected extra path");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given import with duplicate --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "import", "file.json", "--json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "duplicate `--json`");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given the import result writer when writing a report then it emits the import document" {
    const gpa = std.testing.allocator;
    var report = registry.ImportReport.init(.single_file);
    defer report.deinit(gpa);
    try report.addEvent(gpa, "token.json", .imported, null);
    try report.addEvent(gpa, "broken.json", .skipped, "MissingEmail");

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeImportResult(&aw.writer, &report, "standard", "/tmp/imports", null, null);
    const text = aw.written();
    try expectContains(text, "\"schema_version\":1");
    try expectContains(text, "\"command\":\"import\"");
    try expectContains(text, "\"mode\":\"standard\"");
    try expectContains(text, "\"source\":\"/tmp/imports\"");
    try expectContains(text, "\"status\":\"imported\"");
    try expectContains(text, "\"status\":\"skipped\"");
    try expectContains(text, "\"reason\":\"MissingEmail\"");
    try expectContains(text, "\"imported_count\":1");
    try expectContains(text, "\"skipped_count\":1");
    try expectContains(text, "\"active_account_key\":null");
}

test "Scenario: Given the import result writer when writing a purge report then registry_rebuilt is present" {
    const gpa = std.testing.allocator;
    var report = registry.ImportReport.init(.scanned);
    defer report.deinit(gpa);
    try report.addEvent(gpa, "auth.json (active)", .imported, null);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeImportResult(&aw.writer, &report, "purge", "~/.codex/accounts", null, true);
    const text = aw.written();
    try expectContains(text, "\"mode\":\"purge\"");
    try expectContains(text, "\"registry_rebuilt\":true");
}

test "Scenario: Given export with --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "export", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .export_auth => |opts| try std.testing.expect(opts.json),
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given export with a destination and --json when parsing then both are preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "export", "backup-dir", "--cpa", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .export_auth => |opts| {
                try std.testing.expect(opts.json);
                try std.testing.expectEqualStrings("backup-dir", opts.dest_path.?);
                try std.testing.expectEqual(cli.types.ExportFormat.cpa, opts.format);
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given export with duplicate --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "export", "--json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "duplicate `--json`");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given the export result writer when writing a summary then it emits the export document" {
    const gpa = std.testing.allocator;
    var summary = registry.ExportSummary{
        .dest_path = try gpa.dupe(u8, "/tmp/backup"),
        .exported = 2,
        .skipped = 1,
    };
    defer summary.deinit(gpa);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeExportResult(&aw.writer, &summary, "cpa");
    const text = aw.written();
    try expectContains(text, "\"schema_version\":1");
    try expectContains(text, "\"command\":\"export\"");
    try expectContains(text, "\"format\":\"cpa\"");
    try expectContains(text, "\"destination\":\"/tmp/backup\"");
    try expectContains(text, "\"exported_count\":2");
    try expectContains(text, "\"skipped_count\":1");
}

test "Scenario: Given app with --json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "app", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .app => |opts| try std.testing.expect(opts.json),
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given app with --std and --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "app", "--std", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "`--std` cannot be combined with `--json`");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given app with duplicate --json when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "app", "--json", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "duplicate `--json`");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given the app result writer when writing then it emits the app document" {
    const gpa = std.testing.allocator;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeAppResult(&aw.writer, "already_running", "com.openai.codex", null);
    const text = aw.written();
    try expectContains(text, "\"schema_version\":1");
    try expectContains(text, "\"command\":\"app\"");
    try expectContains(text, "\"status\":\"already_running\"");
    try expectContains(text, "\"app_id\":\"com.openai.codex\"");
    try expectContains(text, "\"codex_cli_path\":null");
}

test "Scenario: Given login with device auth and json when parsing then both flags are preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "login", "--device-auth", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .login => |opts| {
                try std.testing.expect(opts.json);
                try std.testing.expect(opts.device_auth);
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given login with json but no device auth when parsing then json usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "login", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| {
            try std.testing.expect(usage_err.json);
            try expectContains(usage_err.message, "`login --json` requires `--device-auth`.");
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given the login awaiting-user writer when writing then it emits the phase document" {
    const gpa = std.testing.allocator;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeLoginAwaitingUser(&aw.writer, "https://auth.openai.com/codex/device", "TEST-1234");
    const text = aw.written();
    try expectContains(text, "\"schema_version\":1");
    try expectContains(text, "\"command\":\"login\"");
    try expectContains(text, "\"mode\":\"device_auth\"");
    try expectContains(text, "\"phase\":\"awaiting_user\"");
    try expectContains(text, "\"verification_url\":\"https://auth.openai.com/codex/device\"");
    try expectContains(text, "\"user_code\":\"TEST-1234\"");
}

test "Scenario: Given the login completed writer when writing then it emits the completed document" {
    const gpa = std.testing.allocator;
    var account = workflows.results.AccountView{
        .number = 1,
        .account_key = try gpa.dupe(u8, "user-1::acc-1"),
        .email = try gpa.dupe(u8, "a@example.com"),
        .alias = null,
        .account_name = null,
        .plan = .plus,
        .auth_mode = .chatgpt,
        .active = true,
        .created_at = 1730000000,
        .last_used_at = null,
        .usage = .{
            .source = .cache,
            .refresh = .{ .requested = false, .method = null, .status = .not_requested },
        },
    };
    defer account.deinit(gpa);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeLoginCompleted(&aw.writer, "user-1::acc-1", &account);
    const text = aw.written();
    try expectContains(text, "\"phase\":\"completed\"");
    try expectContains(text, "\"active_account_key\":\"user-1::acc-1\"");
    try expectContains(text, "\"account\"");
    try expectContains(text, "\"email\":\"a@example.com\"");
}

test "Scenario: Given the login failed writer when writing then it emits the failed document" {
    const gpa = std.testing.allocator;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeLoginFailed(&aw.writer, "codex login failed with exit code 1");
    const text = aw.written();
    try expectContains(text, "\"phase\":\"failed\"");
    try expectContains(text, "\"message\":\"codex login failed with exit code 1\"");
}

test "Scenario: Given the version result writer when writing then it emits the capability document" {
    const gpa = std.testing.allocator;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeVersionResult(&aw.writer);
    const text = aw.written();
    try expectContains(text, "\"schema_version\":1");
    try expectContains(text, "\"command\":\"version\"");
    try expectContains(text, "\"supported_commands\"");
    try expectContains(text, "\"list\"");
    try expectContains(text, "\"alias\"");
}

test "Scenario: Given the alias result writer when writing a set result then it emits the alias document" {
    const gpa = std.testing.allocator;
    var result = workflows.results.AliasResult{
        .updated = .{
            .number = 1,
            .account_key = try gpa.dupe(u8, "user-1::acc-1"),
            .email = try gpa.dupe(u8, "a@example.com"),
            .alias = try gpa.dupe(u8, "work"),
            .account_name = null,
            .plan = .business,
            .auth_mode = .chatgpt,
            .active = false,
            .created_at = 1730000000,
            .last_used_at = null,
            .usage = .{
                .source = .cache,
                .refresh = .{ .requested = false, .method = null, .status = .not_requested },
            },
        },
    };
    defer result.deinit(gpa);

    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeAliasResult(&aw.writer, &result, "set");
    const text = aw.written();
    try expectContains(text, "\"schema_version\":1");
    try expectContains(text, "\"command\":\"alias\"");
    try expectContains(text, "\"operation\":\"set\"");
    try expectContains(text, "\"account_key\":\"user-1::acc-1\"");
    try expectContains(text, "\"alias\":\"work\"");
}

test "Scenario: Given clean with json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "clean", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .clean => |opts| try std.testing.expect(opts.json),
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given clean background with json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "clean", "background", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .clean => |opts| {
                try std.testing.expect(opts.json);
                try std.testing.expectEqual(cli.types.CleanTarget.background, opts.target);
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given config get with json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "config", "get", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .config => |opts| switch (opts) {
                .get => |get_opts| try std.testing.expect(get_opts.json),
                .live => return error.TestExpectedEqual,
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given config get without json when parsing then usage error is returned" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "config", "get" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .usage_error => |usage_err| try expectContains(usage_err.message, "`config get` requires `--json`"),
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given config live with interval and json when parsing then json mode is preserved" {
    const gpa = std.testing.allocator;
    const args = [_][:0]const u8{ "codex-auth", "config", "live", "--interval", "120", "--json" };
    var result = try cli.commands.parseArgs(gpa, &args);
    defer cli.commands.freeParseResult(gpa, &result);

    switch (result) {
        .command => |cmd| switch (cmd) {
            .config => |opts| switch (opts) {
                .live => |live_opts| {
                    try std.testing.expect(live_opts.json);
                    try std.testing.expectEqual(@as(u16, 120), live_opts.interval_seconds);
                },
                .get => return error.TestExpectedEqual,
            },
            else => return error.TestExpectedEqual,
        },
        else => return error.TestExpectedEqual,
    }
}

test "Scenario: Given the clean result writer when writing then it emits the clean document" {
    const gpa = std.testing.allocator;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    const view = cli.json_output.CleanResultView{
        .target = "accounts",
        .auth_backups_removed = 1,
        .registry_backups_removed = 2,
        .stale_snapshot_files_removed = 3,
    };
    try cli.json_output.writeCleanResult(&aw.writer, &view);
    const text = aw.written();
    try expectContains(text, "\"command\":\"clean\"");
    try expectContains(text, "\"target\":\"accounts\"");
    try expectContains(text, "\"auth_backups_removed\":1");
    try expectContains(text, "\"registry_backups_removed\":2");
    try expectContains(text, "\"stale_snapshot_files_removed\":3");
}

test "Scenario: Given the config result writer when writing then it emits the config document" {
    const gpa = std.testing.allocator;
    var aw: std.Io.Writer.Allocating = .init(gpa);
    defer aw.deinit();

    try cli.json_output.writeConfigResult(&aw.writer, "live", 120);
    const text = aw.written();
    try expectContains(text, "\"command\":\"config\"");
    try expectContains(text, "\"section\":\"live\"");
    try expectContains(text, "\"interval_seconds\":120");
}
