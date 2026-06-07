const std = @import("std");

// Most of this is copied from https://github.com/Beyley/SDL_shadercross_zig/blob/master/build.zig.
fn addDeps(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    system_include_path: ?std.Build.LazyPath,
    sdl_dep_lib: ?*std.Build.Step.Compile,
    link_cli: bool,
    dxc_support: bool,
    module: *std.Build.Step.Compile,
) ?void {
    const upstream = b.lazyDependency("sdl_shadercross", .{}) orelse return null;
    const dxc_dep: ?*std.Build.Dependency = if (dxc_support)
        b.lazyDependency("dxc", .{
            .target = target,
            .optimize = optimize,
        }) orelse return null
    else
        null;

    if (system_include_path) |val| {
        module.root_module.addSystemIncludePath(val);
    }

    if (sdl_dep_lib) |sdl_lib| {
        module.root_module.linkLibrary(sdl_lib);
    } else module.root_module.linkSystemLibrary("sdl3", .{});

    module.root_module.addIncludePath(upstream.path("include"));
    module.root_module.addCSourceFiles(
        .{
            .root = upstream.path("src"),
            .files = if (link_cli) &.{
                "cli.c",
                "SDL_shadercross.c",
            } else &.{
                "SDL_shadercross.c",
            },
            .flags = if (dxc_support) &.{"-DSDL_SHADERCROSS_DXC"} else &.{},
        },
    );

    const spirv_headers = b.lazyDependency("spirv_headers", .{}) orelse return null;
    const spirv_cross = b.lazyDependency("spirv_cross", .{
        .target = target,
        .optimize = .ReleaseFast, // There is a C bug in spirv-cross upstream! Ignore undefined behavior for now.
        .spv_cross_reflect = true,
        .spv_cross_cpp = false,
    }) orelse return null;
    module.root_module.addIncludePath(spirv_headers.path("include/spirv/1.2/"));
    module.root_module.linkLibrary(spirv_cross.artifact("spirv-cross-c"));

    if (dxc_support) {
        const dxcompiler = dxc_dep.?.artifact("dxcompiler");
        module.root_module.linkLibrary(dxcompiler);
        b.installArtifact(dxcompiler);
        const dxil = dxc_dep.?.artifact("dxil");
        module.root_module.linkLibrary(dxil);
        b.installArtifact(dxil);
    }
}

/// Build the CLI executable.
pub fn cli(
    b: *std.Build,
    system_include_path: ?std.Build.LazyPath,
    use_sdl_dep_lib: bool,
    dxc_support: bool,
) ?*std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "shadercross",
        .root_module = b.createModule(.{
            .link_libc = true,
            .target = b.graph.host,
            .optimize = .ReleaseFast,
        }),
    });
    const sdl_dep_lib: ?*std.Build.Step.Compile = if (use_sdl_dep_lib) brk: {
        const lib = (b.lazyDependency("sdl", .{ .target = b.graph.host, .optimize = .ReleaseFast }) orelse return null).artifact("SDL3");
        if (system_include_path) |val|
            lib.root_module.addSystemIncludePath(val);
        break :brk lib;
    } else null;
    addDeps(b, b.graph.host, .ReleaseFast, system_include_path, sdl_dep_lib, true, dxc_support, exe) orelse return null;
    return exe;
}

pub fn setup(
    b: *std.Build,
    sdl3: *std.Build.Module,
    translate_c: *std.Build.Step.TranslateC,
    sdl_dep_lib: ?*std.Build.Step.Compile,
    linkage: std.builtin.LinkMode,
    cfg: struct { optimize: std.builtin.OptimizeMode, target: std.Build.ResolvedTarget },
    system_include_path: ?std.Build.LazyPath,
    dxc_support: bool,
) void {
    const upstream = b.lazyDependency("sdl_shadercross", .{}) orelse return;

    const target = cfg.target;
    const lib = b.addLibrary(.{
        .name = "SDL3_shadercross",
        .version = .{ .major = 3, .minor = 0, .patch = 0 },
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = cfg.optimize,
            .link_libc = true,
        }),
    });
    if (addDeps(b, target, cfg.optimize, system_include_path, sdl_dep_lib, false, dxc_support, lib) == null)
        return;

    translate_c.addIncludePath(upstream.path("include"));
    lib.root_module.addIncludePath(upstream.path("include"));
    lib.root_module.addIncludePath(upstream.path("src"));

    sdl3.linkLibrary(lib);
}
