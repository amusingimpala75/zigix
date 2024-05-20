const std = @import("std");

const ZigixSymlinkStep = struct {
    name: []const u8,
    step: std.Build.Step,

    fn makeFn(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
        const b = step.owner;
        const symlink_step: *ZigixSymlinkStep = @fieldParentPtr("step", step);
        const zigix_abspath = try std.fmt.allocPrint(b.allocator, "{s}/bin/zigix", .{b.install_prefix});
        defer b.allocator.free(zigix_abspath);
        const util_abspath = try std.fmt.allocPrint(b.allocator, "{s}/bin/{s}", .{ b.install_prefix, symlink_step.name });
        defer b.allocator.free(util_abspath);
        const already_exists = blk: {
            std.fs.accessAbsolute(util_abspath, .{}) catch |err| switch (err) {
                error.FileNotFound => break :blk false,
                else => return err,
            };
            break :blk true;
        };
        if (already_exists) {
            try std.fs.deleteFileAbsolute(util_abspath);
        }
        try std.fs.symLinkAbsolute(zigix_abspath, util_abspath, .{});
    }

    fn init(b: *std.Build, name: []const u8) !*ZigixSymlinkStep {
        const step: *ZigixSymlinkStep = try b.allocator.create(ZigixSymlinkStep);
        step.* = .{
            .name = name,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = name,
                .owner = b,
                .makeFn = &makeFn,
            }),
        };
        return step;
    }
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigix",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const exe_install_step = b.addInstallArtifact(exe, .{});
    b.getInstallStep().dependOn(&exe_install_step.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);
    // Ensure version being used for tests is also the one we are using
    run_exe_unit_tests.step.dependOn(&exe_install_step.step);

    for (@import("src/programs.zig").program_names) |prog| {
        const step = try ZigixSymlinkStep.init(b, prog);
        step.step.dependOn(&exe_install_step.step);
        b.getInstallStep().dependOn(&step.step);
    }

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
