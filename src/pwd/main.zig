const std = @import("std");

const Flags = enum {
    L,
    P,

    fn parse(args: *std.process.ArgIterator) !Flags {
        var ret: Flags = .L;
        while (args.next()) |arg| {
            if (arg.len >= 2 and arg[0] == '-') {
                for (arg[1..]) |char| switch (char) {
                    'L' => ret = .L,
                    'P' => ret = .P,
                    else => return error.InvalidArg,
                };
            }
        }
        return ret;
    }
};

pub fn main(args: *std.process.ArgIterator, allocator: std.mem.Allocator) !u8 {
    const mode = try Flags.parse(args);

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &buf);

    if (mode == .L) {
        try lPrint(allocator, cwd);
    } else {
        try pPrint(cwd);
    }
    return 0;
}

fn lPrint(allocator: std.mem.Allocator, cwd: []const u8) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const pwd_env = env_map.get("PWD") orelse {
        try pPrint(cwd);
        return;
    };

    var i: usize = 0;
    while (i < pwd_env.len) : (i += 1) {
        if (pwd_env[i] == '/' and
            i + 1 < pwd_env.len and pwd_env[i + 1] == '.')
        {
            // Check for just that '.'
            if (i + 2 >= pwd_env.len or pwd_env[i + 2] == '/') {
                try pPrint(cwd);
                return;
            }
            // Check for '..'
            if (i + 2 == pwd_env.len and pwd_env[i + 2] == '.' and
                (i + 3 >= pwd_env.len or pwd_env[i + 3] == '/'))
            {
                try pPrint(cwd);
                return;
            }
        }
    }

    const pwd_dir = try std.fs.openDirAbsolute(
        pwd_env,
        .{ .access_sub_paths = false },
    );
    var buf_pwd: [std.fs.max_path_bytes]u8 = undefined;
    const pwd_env_expanded = try pwd_dir.realpath(".", &buf_pwd);

    if (!std.mem.eql(u8, pwd_env_expanded, cwd)) {
        try pPrint(cwd);
        return;
    }

    try printVal(pwd_env_expanded);
}

fn pPrint(cwd: []const u8) !void {
    try printVal(cwd);
}

fn printVal(dir: []const u8) !void {
    var bw = std.io.bufferedWriter(std.io.getStdOut().writer());
    const writer = bw.writer();
    try writer.print("{s}\n", .{dir});
    try bw.flush();
}
