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

const Args = struct {
    const FileList = std.ArrayList([]const u8);

    l: bool = false,
    w: bool = false,
    cm: BytesMode = .neither,
    files: FileList,
    parsed_options: ArgumentParser.ParsedOptions,

    fn parse(args: *std.process.ArgIterator, allocator: std.mem.Allocator) !Args {
        const options = blk: {
            var option_map: ArgumentParser.OptionMap = .{};
            option_map.putAllNoArgument("lw");
            option_map.putAllMutex("cm");
            break :blk option_map;
        };
        const parsed_options = try ArgumentParser.parse(options, args, allocator);

        return .{
            .l = parsed_options.options.contains('l'),
            .w = parsed_options.options.contains('w'),
            .cm = if (parsed_options.options.contains('m'))
                .chars
            else if (!parsed_options.options.contains('c'))
                .neither
            else
                .bytes,
            .files = parsed_options.operands,
            .parsed_options = parsed_options,
        };
    }

    fn deinit(self: *Args) void {
        self.parsed_options.deinit();
    }

    fn hasFlags(self: Args) bool {
        return self.l == true or self.w == true or self.cm != .neither;
    }
};

pub fn main(argsIterator: *std.process.ArgIterator, allocator: std.mem.Allocator) !u8 {
    var args = try Args.parse(argsIterator, allocator);
    defer args.deinit();

    if (args.cm == .chars) {
        return error.UnsupportedOperation;
    }

    const count_lines = !args.hasFlags() or args.l;
    const count_words = !args.hasFlags() or args.w;
    const bytes_mode = if (!args.hasFlags() and args.cm == .neither) .bytes else args.cm;

    if (args.files.items.len == 0) {
        const lines, const words, const bytes = try stdinInfo(count_lines or count_words);

        try printInfo(
            if (count_lines) lines else null,
            if (count_words) words else null,
            if (bytes_mode != .neither) bytes else null,
            "",
        );

        return 0;
    }

    var sum_lines: usize = 0;
    var sum_words: usize = 0;
    var sum_bytes: usize = 0;

    var ret: u8 = 0;

    for (args.files.items) |file| {
        const line_count, const word_count, const byte_count = fileInfo(file, count_lines or count_words) catch |err| {
            switch (err) {
                error.IsADirectory => try io.stdErrPrint("wc: {s} is a directory\n", .{file}),
                else => try io.stdErrPrint("wc: error printing {s}: {!}\n", .{ file, err }),
            }
            ret = 1;
            continue;
        };

        sum_lines += line_count;
        sum_words += word_count;
        sum_bytes += byte_count;

        try printInfo(
            if (count_lines) line_count else null,
            if (count_words) word_count else null,
            if (bytes_mode != .neither) byte_count else null,
            file,
        );
    }

    if (args.files.items.len > 1) {
        try printInfo(
            if (count_lines) sum_lines else null,
            if (count_words) sum_words else null,
            if (bytes_mode != .neither) sum_bytes else null,
            "total",
        );
    }

    return ret;
}

fn fileInfo(filename: []const u8, more_than_just_bytes: bool) !struct { usize, usize, usize } {
    const f = try fs.openFileMaybeAbsolute(filename, .{});
    defer f.close();

    const stat = try f.stat();
    if (stat.kind == .directory) {
        return error.IsADirectory;
    }

    if (more_than_just_bytes) {
        return try readerInfo(f.reader());
    }

    return .{ 0, 0, stat.size };
}

fn stdinInfo(more_than_just_bytes: bool) !struct { usize, usize, usize } {
    const stdin = std.io.getStdIn();

    if (more_than_just_bytes) {
        return try readerInfo(stdin.reader());
    } else {
        return .{ 0, 0, (try stdin.stat()).size };
    }
}

fn readerInfo(reader: anytype) !struct { usize, usize, usize } {
    var br = std.io.bufferedReader(reader);
    const r = br.reader();

    var in_word = false;

    var lines: usize = 0;
    var words: usize = 0;
    var bytes: usize = 0;

    while (r.readByte()) |byte| {
        byteScan(byte, &lines, &words, &in_word);
        bytes += 1;
    } else |err| switch (err) {
        error.EndOfStream => {},
        else => |e| return e,
    }

    return .{ lines, words, bytes };
}

fn byteScan(byte: u8, lines_counter: *usize, words_counter: *usize, in_word: *bool) void {
    if (byte == '\n') {
        lines_counter.* += 1;
    }
    if (!in_word.* and !isWhitespace(byte)) {
        words_counter.* += 1;
        in_word.* = true;
    } else if (in_word.* and isWhitespace(byte)) {
        in_word.* = false;
    }
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
fn printInfo(count_lines: ?usize, count_words: ?usize, count_bytes: ?usize, filename: []const u8) !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();

    if (count_lines) |count| {
        try writer.print("{: >8} ", .{count});
    }
    if (count_words) |count| {
        try writer.print("{: >8} ", .{count});
    }
    if (count_bytes) |count| {
        try writer.print("{: >8} ", .{count});
    }
    try writer.print("{s: <}\n", .{filename});
    try bw.flush();
}
