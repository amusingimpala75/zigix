const std = @import("std");

fn writeFile(file: std.fs.File, comptime fmt: []const u8, args: anytype) !void {
    var bw = std.io.bufferedWriter(file.writer());
    const writer = bw.writer();
    try writer.print(fmt, args);
    try bw.flush();
}

pub fn stdErrPrint(comptime fmt: []const u8, args: anytype) !void {
    try writeFile(std.io.getStdErr(), fmt, args);
}

pub fn stdOutPrint(comptime fmt: []const u8, args: anytype) !void {
    try writeFile(std.io.getStdOut(), fmt, args);
}
