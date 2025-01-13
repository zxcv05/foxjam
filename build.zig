const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Dependencies

    const standard_options = .{ .target = target, .optimize = optimize };

    const raylib_dependency = b.dependency("raylib", standard_options);
    const raylib_library = raylib_dependency.artifact("raylib");
    const raylib_module = raylib_dependency.module("raylib");
    const raygui_module = raylib_dependency.module("raygui");

    if (target.query.os_tag == .emscripten)
        return build_emscripten(b, target, optimize, raylib_module, raygui_module, raylib_library);

    // Main executable

    const exe = b.addExecutable(.{ .root_source_file = b.path("src/main.zig"), .name = "foxjam", .optimize = optimize, .target = target });

    exe.root_module.strip = optimize != .Debug;
    exe.link_gc_sections = true;

    exe.root_module.addImport("raylib", raylib_module);
    exe.root_module.addImport("raygui", raygui_module);

    exe.linkLibrary(raylib_library);

    const run = b.addRunArtifact(exe);
    if (b.args) |args| run.addArgs(args);

    const step = b.step("run", "Run program");
    step.dependOn(&run.step);

    b.installArtifact(exe);

    // Test

    const testing = b.addTest(.{ .root_source_file = b.path("src/main.zig"), .name = "foxjam", .optimize = optimize, .target = target });
    testing.root_module = exe.root_module;

    const test_run = b.addRunArtifact(testing);
    if (b.args) |args| test_run.addArgs(args);

    const test_step = b.step("test", "Test program");
    test_step.dependOn(&test_run.step);

    // Dist

    const dist_step = b.step("dist", "Create dist/");
    const dist_dir: std.Build.InstallDir = .{ .custom = "dist" };

    const copy_res = b.addInstallDirectory(.{ .source_dir = .{ .cwd_relative = "res/" }, .install_dir = dist_dir, .install_subdir = "res" });
    const copy_exe = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = dist_dir }, .dest_sub_path = "foxjam" });

    dist_step.dependOn(&copy_res.step);
    dist_step.dependOn(&copy_exe.step);
}

pub fn build_emscripten(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    raylib_module: *std.Build.Module,
    raygui_module: *std.Build.Module,
    raylib_library: *std.Build.Step.Compile,
) !void {
    const raylib = @import("raylib");
    const exe = try raylib.emcc.compileForEmscripten(b, "foxjam", "src/main.zig", target, optimize);

    exe.linkLibrary(raylib_library);
    exe.root_module.addImport("raylib", raylib_module);
    exe.root_module.addImport("raygui", raygui_module);

    const link_step = try raylib.emcc.linkWithEmscripten(b, &[_]*std.Build.Step.Compile{ exe, raylib_library });
    link_step.addArg("--embed-file");
    link_step.addArg("res/");

    b.getInstallStep().dependOn(&link_step.step);

    const emcc_run_step = try raylib.emcc.emscriptenRunStep(b);
    emcc_run_step.step.dependOn(&link_step.step);

    const run_step = b.step("run", "Run program");
    run_step.dependOn(&emcc_run_step.step);
}
