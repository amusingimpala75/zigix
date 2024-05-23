const std = @import("std");

pub fn openFileMaybeAbsoluteOrStdIn(pathname: []const u8, flags: std.fs.File.OpenFlags) !std.fs.File {
    if (std.mem.eql(u8, "-", pathname)) {
        return std.io.getStdIn();
    }
    return try (if (pathname[0] == '/')
        std.fs.openFileAbsolute(pathname, flags)
    else
        std.fs.cwd().openFile(pathname, flags));
}
