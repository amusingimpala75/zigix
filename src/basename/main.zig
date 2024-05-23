const std = @import("std");

const io = @import("io");

pub fn main(args: *std.process.ArgIterator, _: std.mem.Allocator) !u8 {
    try io.stdOutPrint("{s}\n", .{process(args.next().?, args.next())});
    return 0;
}

fn process(string: []const u8, suffix: ?[]const u8) []const u8 {
    if (string.len == 0) {
        return ".";
    }

    const all_slashes = blk: {
        for (string) |char| {
            if (char != '/')
                break :blk false;
        }
        break :blk true;
    };
    if (all_slashes) {
        return "/";
    }

    const basename = std.fs.path.basename(string);

    if (suffix) |suf| {
        if (basename.len > suf.len and
            std.mem.eql(u8, basename[basename.len - suf.len ..], suf))
        {
            return basename[0 .. basename.len - suf.len];
        } else {
            return basename;
        }
    } else {
        return basename;
    }
}

test "null string" {
    try std.testing.expectEqualSlices(u8, ".", process("", null));
}

test "only slashes" {
    try std.testing.expectEqualSlices(
        u8,
        "/",
        process("////////////////////////////", null),
    );
}

test {
    // absolute path
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("/bar/baz/foo", null),
    );
    // relative path
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("bar/baz/foo", null),
    );
    // single entry, relative
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("foo", null),
    );
    // single entry, absolute
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("/foo", null),
    );
    // relative, with extension
    try std.testing.expectEqualSlices(
        u8,
        "main.zig",
        process("src/main.zig", null),
    );
}

test "trailing slashes" {
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("/bar/baz/foo/", null),
    );
}

test "suffix removal" {
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("foo.txt", ".txt"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "foo.txt",
        process("foo.txt", "foo"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("/bar/foo.txt", ".txt"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("bar/foo.txt", ".txt"),
    );
    try std.testing.expectEqualSlices(
        u8,
        "foo",
        process("/bar/baz/foo", ""),
    );
}
