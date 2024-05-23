const std = @import("std");

pub fn main(args: *std.process.ArgIterator, _: std.mem.Allocator) !u8 {
    const filename = args.next() orelse return error.MissingFileNameArg;
    try output(process(filename));
    return 0;
}

fn process(filename: []const u8) []const u8 {
    if (std.fs.path.dirname(filename)) |f| {
        return f;
    }
    return if (filename[0] == '/') "/" else ".";
}

test "just slashes" {
    try std.testing.expectEqualSlices(u8, "/", process("/////////////////"));
}

test "absolute paths" {
    try std.testing.expectEqualSlices(
        u8,
        "/foo/bar",
        process("/foo/bar/baz"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "/foo/bar",
        process("/foo/bar/baz/"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "/foo/bar",
        process("/foo/bar/baz.txt"),
    );
}

test "relative paths" {
    try std.testing.expectEqualSlices(
        u8,
        "foo/bar",
        process("foo/bar/baz"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "foo/bar",
        process("foo/bar/baz/"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "foo/bar",
        process("foo/bar/baz.txt"),
    );
}

test "no directory" {
    try std.testing.expectEqualSlices(
        u8,
        ".",
        process("foo_bar_baz.txt"),
    );
}

fn output(str: []const u8) !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();
    try writer.print("{s}\n", .{str});
    try bw.flush();
}
