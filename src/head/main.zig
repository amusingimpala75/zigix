const std = @import("std");

const io = @import("io");
const fs = @import("fs");
const ArgumentParser = @import("../ArgumentParser.zig");

const options = blk: {
    var option_map: ArgumentParser.OptionMap = .{};
    option_map.put(ArgumentParser.Option{
        .flag = 'n',
        .argument = ArgumentParser.Option.Argument.usize(),
    });
    break :blk option_map;
};

pub fn main(args: *std.process.ArgIterator, allocator: std.mem.Allocator) !u8 {
    const parsed = try ArgumentParser.parse(options, args, allocator);
    defer parsed.deinit();

    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();

    const line_count = if (parsed.options.contains('n'))
        parsed.options.get('n').argument.usize
    else
        10;

    var ret: u8 = 0;

    for (parsed.operands.items, 0..) |filename, idx| {
        if (parsed.operands.items.len > 1) {
            if (idx != 0) {
                try writer.writeByte('\n');
            }
            try writer.print("==> {s} <==\n", .{filename});
            try bw.flush();
        }
        const is_stdin = std.mem.eql(u8, "-", filename);
        const file = try fs.openFileOmni(filename, .{});
        defer {
            if (!is_stdin) {
                file.close();
            }
        }
        if ((try file.stat()).kind != .file) {
            try io.stdErrPrint("head: {s} is not a file\n", .{filename});
            ret = 1;
        }
        var br = std.io.bufferedReader(file.reader());
        try printPartial(br.reader(), writer, line_count);
        try bw.flush();
    }
    return ret;
}

fn printPartial(reader: anytype, writer: anytype, lines: usize) !void {
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
}
