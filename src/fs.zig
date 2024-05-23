const std = @import("std");

pub fn openFileMaybeAbsolute(pathname: []const u8, flags: std.fs.File.OpenFlags) !std.fs.File {
    return try (if (pathname[0] == '/')
        std.fs.openFileAbsolute(pathname, flags)
    else
        std.fs.cwd().openFile(pathname, flags));
}
