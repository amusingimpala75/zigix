// TODO:
// implement locales and localization
// once this is done, we can finish the
// -m implementation, as that requires
// understanding how wide characters are.

const std = @import("std");

const ArgumentParser = @import("../ArgumentParser.zig");

const io = @import("io");
const fs = @import("fs");

const BytesMode = enum {
    bytes,
    chars,
    neither,
};

const DisplayMode = struct {
    show_line_count: bool,
    show_word_count: bool,
    show_byte_count: bool,
};

const Count = struct {
    line: usize = 0,
    word: usize = 0,
    byte: usize = 0,
};

const options = blk: {
    var option_map: ArgumentParser.OptionMap = .{};
    option_map.putAllNoArgument("lw");
    option_map.putAllMutex("cm");
    break :blk option_map;
};

pub fn main(
    args: *std.process.ArgIterator,
    allocator: std.mem.Allocator,
) !u8 {
    const parsed_options = blk: {
        var parsed = try ArgumentParser.parse(options, args, allocator);
        if (parsed.operands.items.len == 0) {
            try parsed.operands.append("-");
        }
        break :blk parsed;
    };
    defer parsed_options.deinit();

    var ret: u8 = 0;

    const no_flags = parsed_options.options.isEmpty();

    const bytes_mode: BytesMode = blk: {
        break :blk if (no_flags or parsed_options.options.contains('c'))
            .bytes
        else if (parsed_options.options.contains('m'))
            return error.UnsupportedOperation
        else
            .neither;
    };

    const display_mode: DisplayMode = .{
        .show_line_count = no_flags or parsed_options.options.contains('l'),
        .show_word_count = no_flags or parsed_options.options.contains('w'),
        .show_byte_count = bytes_mode != .neither,
    };

    const scan_manually =
        display_mode.show_line_count or display_mode.show_word_count;

    var sum: Count = .{};

    for (parsed_options.operands.items) |file| {
        const count = fileInfo(file, scan_manually) catch |err| {
            switch (err) {
                error.IsADirectory => try io.stdErrPrint(
                    "wc: {s} is a directory\n",
                    .{file},
                ),
                else => try io.stdErrPrint(
                    "wc: error printing {s}: {!}\n",
                    .{ file, err },
                ),
            }
            ret = 1;
            continue;
        };

        sum.line += count.line;
        sum.word += count.word;
        sum.byte += count.byte;

        // show nothing if reading from stdin
        const display_name = if (std.mem.eql(u8, "-", file))
            ""
        else
            file;

        try printInfo(display_mode, count, display_name);
    }

    if (parsed_options.operands.items.len > 1) {
        try printInfo(display_mode, sum, "total");
    }

    return ret;
}

fn fileInfo(filename: []const u8, more_than_just_bytes: bool) !Count {
    const f = try fs.openFileOmni(filename, .{});

    // Only close the file if it wasn't stdin
    defer {
        if (!std.mem.eql(u8, "-", filename)) {
            f.close();
        }
    }

    const stat = try f.stat();

    if (stat.kind == .directory) {
        return error.IsADirectory;
    }

    if (!more_than_just_bytes) {
        return .{ .byte = stat.size };
    }

    var br = std.io.bufferedReader(f.reader());
    const r = br.reader();

    var in_word = false;

    var count: Count = .{};

    while (r.readByte()) |byte| {
        if (byte == '\n') {
            count.line += 1;
        }

        if (!in_word and !isWhitespace(byte)) {
            count.word += 1;
            in_word = true;
        } else if (in_word and isWhitespace(byte)) {
            in_word = false;
        }

        count.byte += 1;
    } else |err| switch (err) {
        error.EndOfStream => {}, // We don't care if EOF, just terminate
        else => |e| return e,
    }

    return count;
}

fn isWhitespace(c: u8) bool {
    return switch (c) {
        ' ',
        '\x0c',
        '\n',
        '\r',
        '\t',
        '\x0b',
        => true,
        else => false,
    };
}

// TODO dynamically adjust the size of the padding
fn printInfo(
    display_mode: DisplayMode,
    count: Count,
    filename: []const u8,
) !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();

    if (display_mode.show_line_count) {
        try writer.print("{: >8} ", .{count.line});
    }
    if (display_mode.show_word_count) {
        try writer.print("{: >8} ", .{count.word});
    }
    if (display_mode.show_byte_count) {
        try writer.print("{: >8} ", .{count.byte});
    }
    try writer.print("{s: <}\n", .{filename});
    try bw.flush();
}
