const std = @import("std");
const program_names = @import("program_names.zig");

const entrypoint = fn (*std.process.ArgIterator, std.mem.Allocator) anyerror!u8;

const program_imports = [_]type{
    @import("basename/main.zig"),
    @import("dirname/main.zig"),
    @import("false/main.zig"),
    @import("head/main.zig"),
    @import("pwd/main.zig"),
    @import("true/main.zig"),
    @import("wc/main.zig"),
};

pub const program_entrypoints = acquireEntrypoints(&program_imports);

fn acquireEntrypoints(comptime imports: []const type) [imports.len]*const entrypoint {
    comptime {
        var entrypoints: [imports.len]*const entrypoint = undefined;
        for (imports, 0..) |import, idx| {
            entrypoints[idx] = &import.main;
        }
        const ret = entrypoints[0..entrypoints.len].*;
        return ret;
    }
}

comptime {
    std.debug.assert(program_names.names.len == program_entrypoints.len);
    std.debug.assert(program_names.names.len == program_imports.len);
}
