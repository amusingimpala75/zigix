const std = @import("std");

const io = @import("io");

const ArgumentParser = @import("../ArgumentParser.zig");

const options = blk: {
    var option_map: ArgumentParser.OptionMap = .{};
    option_map.putAllMutex("LP");
    break :blk option_map;
};

pub fn main(args: *std.process.ArgIterator, allocator: std.mem.Allocator) !u8 {
    const parsed = try ArgumentParser.parse(options, args, allocator);
    defer parsed.deinit();

    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = try std.fs.cwd().realpath(".", &buf);

    if (parsed.options.contains('L')) {
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

    try io.stdOutPrint("{s}\n", .{pwd_env_expanded});
}

fn pPrint(cwd: []const u8) !void {
    try io.stdOutPrint("{s}\n", .{cwd});
}
