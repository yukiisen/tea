const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const zmath = b.dependency("zmath", .{ .target = target, .optimize = optimize });
    const zopengl = b.dependency("zopengl", .{ .target = target });
    const zstbi = b.dependency("zstbi", .{ .target = target, .optimize = optimize });

    exe_mod.addImport("zmath", zmath.module("root"));
    exe_mod.addImport("zopengl", zopengl.module("root"));
    exe_mod.addImport("zstbi", zstbi.module("root"));

    exe_mod.linkSystemLibrary("c", .{});
    exe_mod.linkSystemLibrary("glfw", .{});

    exe_mod.addIncludePath(b.path("include/"));

    exe_mod.addCSourceFile(.{
        .file = b.path("./deps/libraries.c"),
        .flags = &.{ "-lpthread", "-ldl" },
    });

    const exe = b.addExecutable(.{
        .name = "tea",
        .root_module = exe_mod,
    });

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
