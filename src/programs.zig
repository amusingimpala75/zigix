const std = @import("std");

const entrypoint = fn (*std.process.ArgIterator, std.mem.Allocator) anyerror!u8;

pub const program_names = [_][]const u8{
    "basename",
    "dirname",
    "false",
    "pwd",
    "true",
    "wc",
};

pub const program_imports = [_]type{
    @import("basename/main.zig"),
    @import("dirname/main.zig"),
    @import("false/main.zig"),
    @import("pwd/main.zig"),
    @import("true/main.zig"),
    @import("wc/main.zig"),
};

pub const program_entrypoints = [_]*const entrypoint{
    &program_imports[0].main,
    &program_imports[1].main,
    &program_imports[2].main,
    &program_imports[3].main,
    &program_imports[4].main,
    &program_imports[5].main,
};

comptime {
    std.debug.assert(program_names.len == program_entrypoints.len);
    std.debug.assert(program_names.len == program_imports.len);
}
