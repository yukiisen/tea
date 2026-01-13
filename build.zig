const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("sekai", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    const zmath = b.dependency("zmath", .{});

    const exe = b.addExecutable(.{
        .name = "sekai",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "sekai", .module = mod },
                .{ .name = "zmath", .module = zmath.module("root") },
            },
        }),
    });

    exe.root_module.linkSystemLibrary("c", .{});
    exe.root_module.linkSystemLibrary("glfw", .{});
    exe.root_module.linkSystemLibrary("gl", .{});

    exe.root_module.addIncludePath(b.path("include/"));

    exe.root_module.addCSourceFile(.{
        .file = b.path("./deps/libraries.c"),
        .flags = &.{ "-lpthread", "-ldl" },
    });

    exe.root_module.addCSourceFile(.{
        .file = b.path("./deps/glad.c"),
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
