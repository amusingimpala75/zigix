const std = @import("std");

pub fn stdErrPrint(comptime fmt: []const u8, args: anytype) !void {
    var bw = std.io.bufferedWriter(std.io.getStdErr().writer());
    const writer = bw.writer();
    try writer.print(fmt, args);
    try bw.flush();
}
