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
    for (
        program_names.names,
        programs.program_entrypoints,
    ) |name, entrypoint| {
        if (std.mem.eql(u8, prog_name, name)) {
            found_prog = true;
            const exit_code = entrypoint(&args, allocator) catch |err| {
                exitError(name, err);
            };
            std.process.exit(exit_code);
        }
    }

    if (!found_prog) {
        exitError("zigix", error.NoSubProgram);
    }
}

fn exitError(program_name: []const u8, err: anyerror) noreturn {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();
    writer.print("{s}: {!}\n", .{ program_name, err }) catch unreachable;
    bw.flush() catch unreachable;
    std.process.exit(1);
}

test {
    _ = programs.program_entrypoints;
}
