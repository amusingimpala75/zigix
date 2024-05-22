const std = @import("std");

const programs = @import("programs.zig");
const program_names = @import("program_names.zig");

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

pub fn main() !void {
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    const prog_name = std.fs.path.basename(args.next().?);
    var found_prog = false;
    for (0..program_names.names.len) |idx| {
        if (std.mem.eql(u8, prog_name, program_names.names[idx])) {
            found_prog = true;
            const exit_code = programs.program_entrypoints[idx](&args, allocator) catch |err| exitError(err);
            std.process.exit(exit_code);
        }
    }

    if (!found_prog) {
        exitError(error.NoSubProgram);
    }
}

fn exitError(err: anyerror) noreturn {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();
    writer.print("{!}\n", .{err}) catch unreachable;
    bw.flush() catch unreachable;
    std.process.exit(1);
}

test {
    _ = programs.program_entrypoints;
}
