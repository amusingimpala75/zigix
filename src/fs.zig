const std = @import("std");

/// Opens a file with the name `pathname`
/// in one of three ways:
/// - `pathname` is '-' means from stdin
/// - `pathname` starts with '/' means
///   it is an absolute path
/// - otherwise `pathname` is a relative
///   path
pub fn openFileOmni(
    pathname: []const u8,
    flags: std.fs.File.OpenFlags,
) !std.fs.File {
    if (std.mem.eql(u8, "-", pathname)) {
        return std.io.getStdIn();
    }
    return try (if (pathname[0] == '/')
        std.fs.openFileAbsolute(pathname, flags)
    else
        std.fs.cwd().openFile(pathname, flags));
}
