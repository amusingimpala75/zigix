const std = @import("std");

const FileList = std.ArrayList([]const u8);

const Args = struct {
    count: usize = 10,
    files: FileList,

    fn init(
        args: *std.process.ArgIterator,
        allocator: std.mem.Allocator,
    ) !Args {
        var ret: Args = .{ .files = FileList.init(allocator) };
        while (args.next()) |arg| {
            if (std.mem.eql(u8, arg, "-n")) {
                const option_arg =
                    args.next() orelse return error.MissingOptionArg;
                ret.count = try std.fmt.parseInt(usize, option_arg, 10);
            } else {
                try ret.files.append(arg);
            }
        }
        return ret;
    }

    fn deinit(self: Args) void {
        self.files.deinit();
    }
};

fn openFileAbsoluteUnknown(pathname: []const u8) !std.fs.File {
    return try if (pathname[0] == '/')
        std.fs.openFileAbsolute(pathname, .{})
    else
        std.fs.cwd().openFile(pathname, .{});
}

pub fn main(args: *std.process.ArgIterator, allocator: std.mem.Allocator) !u8 {
    const processed_args = try Args.init(args, allocator);
    defer processed_args.deinit();
    var ret: u8 = 0;
    for (processed_args.files.items, 0..) |filename, idx| {
        if (processed_args.files.items.len > 1) {
            var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
            const writer = bw.writer();
            if (idx != 0) {
                try writer.writeByte('\n');
            }
            try writer.print("==> {s} <==\n", .{filename});
            try bw.flush();
        }
        const is_stdin = std.mem.eql(u8, "-", filename);
        const file: ?std.fs.File = if (is_stdin)
            null
        else
            try openFileAbsoluteUnknown(filename);
        defer {
            if (file) |f| {
                f.close();
            }
        }
        if (file) |f| {
            if ((try f.stat()).kind != .file) {
                var bw = std.io.bufferedWriter(std.io.getStdErr().writer());
                const writer = bw.writer();
                try writer.print("head: {s} is not a file\n", .{filename});
                try bw.flush();
                ret = 1;
            }
        }
        const reader = if (is_stdin)
            std.io.getStdIn().reader()
        else
            file.?.reader();
        var br = std.io.bufferedReader(reader);
        try printPartial(br.reader(), processed_args.count);
    }
    return ret;
}

fn printPartial(reader: anytype, lines: usize) !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();

    var line_count: usize = 0;
    while (reader.readByte()) |byte| {
        try writer.writeByte(byte);
        if (byte == '\n') {
            line_count += 1;
            if (line_count >= lines) {
                break;
            }
        }
    } else |_| {} // no problem if we hit EOF

    try bw.flush();
}
