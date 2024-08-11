const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const memMapper = b.dependency("MemMapper", .{
        .target = target,
        .optimize = optimize,
    });

    const lineReader = b.addModule("zigStringUtil", .{
        .root_source_file = b.path("src/LineReader.zig"),
        .target = target,
        .optimize = optimize,
    });

    lineReader.addImport("MemMapper", memMapper.module("MemMapper"));

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/LineReader.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_unit_tests.root_module.addImport("MemMapper", memMapper.module("MemMapper"));

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
