const std = @import("std");
const app_runtime = @import("runtime.zig");
const terminal_color = @import("../terminal/color.zig");

pub const Stdout = struct {
    buffer: [4096]u8 = undefined,
    writer: std.Io.File.Writer,
    color_enabled: bool = false,

    pub fn init(self: *Stdout) void {
        const file = std.Io.File.stdout();
        // Streaming mode appends at the current file offset, so sequential
        // short-lived writer instances (e.g. the multi-document login flow)
        // write after each other instead of the positional mode's fresh
        // offset 0 overwriting earlier output when stdout is a seekable file.
        self.writer = std.Io.File.Writer.initStreaming(file, app_runtime.io(), &self.buffer);
        self.color_enabled = terminal_color.fileColorEnabled(file);
    }

    pub fn out(self: *Stdout) *std.Io.Writer {
        return &self.writer.interface;
    }
};

pub const Stderr = struct {
    buffer: [4096]u8 = undefined,
    writer: std.Io.File.Writer,
    color_enabled: bool = false,

    pub fn init(self: *Stderr) void {
        const file = std.Io.File.stderr();
        self.writer = std.Io.File.Writer.initStreaming(file, app_runtime.io(), &self.buffer);
        self.color_enabled = terminal_color.fileColorEnabled(file);
    }

    pub fn out(self: *Stderr) *std.Io.Writer {
        return &self.writer.interface;
    }
};
