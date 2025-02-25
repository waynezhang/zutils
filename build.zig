const std = @import("std");

const Dependency = struct {
    name: []const u8,
    module: ?[]const u8 = null,
    link: ?[]const u8 = null,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const deps = &[_]Dependency{};

    const mod = b.addModule("zutils", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addStaticLibrary(.{
        .name = "zutils",
        .root_source_file = mod.root_source_file.?,
        .target = target,
        .optimize = optimize,
    });
    lib.root_module.addImport("zutils", mod);

    b.installArtifact(lib);
    appendDependencies(b, lib, target, optimize, deps);

    const test_deps = &[_]Dependency{.{
        .name = "protest",
    }};

    const lib_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/test.zig"),
    });
    appendDependencies(b, lib_unit_tests, target, optimize, deps ++ test_deps);

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}

fn appendDependencies(b: *std.Build, comp: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, deps: []const Dependency) void {
    for (deps) |d| {
        const module = d.module orelse d.name;
        const dep = b.dependency(d.name, .{ .target = target, .optimize = optimize });
        const mod = dep.module(module);
        comp.root_module.addImport(d.name, mod);

        if (d.link) |l| {
            comp.linkLibrary(dep.artifact(l));
        }
    }
}
