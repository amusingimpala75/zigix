// TODO:
// implement locales and localization
// once this is done, we can finish the
// -m implementation, as that requires
// understanding how wide characters are.

const std = @import("std");

const arg_help =
    \\-c          Count the bytes in the files
    \\-l          Count the newlines in the files
    \\-m          Count the characters in the files
    \\-w          Count the words in the files
    \\<str>...    The files to be counted
    \\
;

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

    fn parse(args: *std.process.ArgIterator, allocator: std.mem.Allocator) !Args {
        var ret: Args = .{ .files = FileList.init(allocator) };
        while (args.next()) |arg| {
            if (arg.len >= 2 and arg[0] == '-') {
                for (arg[1..]) |flag| switch (flag) {
                    'l' => ret.l = true,
                    'w' => ret.w = true,
                    'c' => ret.cm = .bytes,
                    'm' => ret.cm = .chars,
                    else => return error.UnrecognizedArg,
                };
            } else if (arg.len != 1 or arg[0] != '-') {
                try ret.files.append(arg);
            }
        }
        return ret;
    }

    fn deinit(self: Args) void {
        self.files.deinit();
    }

    fn hasFlags(self: Args) bool {
        return self.l == true or self.w == true or self.cm != .neither;
    }
};

pub fn main(argsIterator: *std.process.ArgIterator, allocator: std.mem.Allocator) !u8 {
    const args = try Args.parse(argsIterator, allocator);
    defer args.deinit();

    if (args.cm == .chars) {
        return error.UnsupportedOperation;
    }

    const count_lines = !args.hasFlags() or args.l;
    const count_words = !args.hasFlags() or args.w;
    const bytes_mode = if (args.cm == .neither) .bytes else args.cm;

    if (args.files.items.len == 0) {
        var br = std.io.bufferedReader(std.io.getStdIn().reader());
        const reader = br.reader();
        const chars = try reader.readAllAlloc(allocator, @as(u32, 1) << 31);
        defer allocator.free(chars);

        const lines, const words = strInfo(chars);
        const bytes = chars.len;

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

    for (args.files.items) |file| {
        const lines, const words, const bytes =
            try fileInfo(file, count_lines or bytes_mode == .chars, count_words, bytes_mode != .neither);
        if (count_lines)
            sum_lines += lines;
        if (count_words)
            sum_words += words;
        if (bytes_mode != .neither)
            sum_bytes += bytes;

        try printInfo(
            if (count_lines) lines else null,
            if (count_words) words else null,
            if (bytes_mode != .neither) bytes else null,
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

    return 0;
}

fn fileInfo(filename: []const u8, need_lines: bool, need_words: bool, need_bytes: bool) !struct { usize, usize, usize } {
    const f: std.fs.File = try (if (filename[0] == '/')
        std.fs.openFileAbsolute(filename, .{})
    else
        std.fs.cwd().openFile(filename, .{}));
    defer f.close();

    var lines: usize = 0;
    var words: usize = 0;

    if (need_lines or need_words) {
        var br = std.io.bufferedReader(f.reader());
        const reader = br.reader();

        var in_word = false;
        while (reader.readByte()) |byte| {
            byteScan(byte, &lines, &words, &in_word);
        } else |_| {} // EOF
    }

    const bytes = if (need_bytes) (try f.stat()).size else 0;
    return .{ lines, words, bytes };
}

fn strInfo(str: []const u8) struct { usize, usize } {
    var lines: usize = 0;
    var words: usize = 0;

    var in_word = false;
    for (str) |byte| {
        byteScan(byte, &lines, &words, &in_word);
    }

    return .{ lines, words };
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
