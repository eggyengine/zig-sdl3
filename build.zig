const std = @import("std");
const zig = @import("builtin");

pub const image = @import("build/image.zig");
pub const net = @import("build/net.zig");
pub const shadercross = @import("build/shadercross.zig");
pub const shaders = @import("build/shaders.zig");
pub const ttf = @import("build/ttf.zig");

const ExampleOptions = struct {
    ext_image: bool,
    ext_net: bool,
    ext_shadercross: bool,
    ext_ttf: bool,
};

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cfg: Config = .{
        .name = "zig-sdl3",
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/sdl3.zig"),
        .version = .{
            .major = 0,
            .minor = 2,
            .patch = 1,
        },
    };

    // C SDL options.
    const c_sdl_preferred_linkage = b.option(
        std.builtin.LinkMode,
        "c_sdl_preferred_linkage",
        "Prefer building statically or dynamically linked libraries (default: static)",
    ) orelse .static;
    const c_sdl_strip = b.option(
        bool,
        "c_sdl_strip",
        "Strip debug symbols (default: varies)",
    ) orelse (optimize == .ReleaseSmall);
    const c_sdl_sanitize_c = b.option(
        std.zig.SanitizeC,
        "c_sdl_sanitize_c",
        "Detect C undefined behavior (default: trap)",
    ) orelse .trap;
    const c_sdl_lto = b.option(
        std.zig.LtoMode,
        "c_sdl_lto",
        "Perform link time optimization (default: false)",
    ) orelse .none;
    const c_sdl_emscripten_pthreads = b.option(
        bool,
        "c_sdl_emscripten_pthreads",
        "Build with pthreads support when targeting Emscripten (default: false)",
    ) orelse false;
    const c_sdl_install_build_config_h = b.option(
        bool,
        "c_sdl_install_build_config_h",
        "Additionally install 'SDL_build_config.h' when installing SDL (default: false)",
    ) orelse false;
    const sdl_system_include_path = b.option(
        std.Build.LazyPath,
        "sdl_system_include_path",
        "System include path for SDL",
    );
    const sdl_sysroot_path = b.option(
        std.Build.LazyPath,
        "sdl_sysroot_path",
        "System include path for SDL",
    );

    if (sdl_sysroot_path) |val| {
        b.sysroot = val.getPath(b);
    }

    const system_sdl = b.systemIntegrationOption("sdl", .{});

    // SDL options.
    const options = b.addOptions();
    const sdl3_main = b.option(bool, "main", "Enable SDL main") orelse false;
    options.addOption(bool, "main", sdl3_main);
    options.addOption(
        usize,
        "log_message_stack_size",
        b.option(
            usize,
            "log_message_stack_size",
            "Default log message stack size",
        ) orelse 1024,
    );
    options.addOption(
        usize,
        "renderer_debug_text_stack_size",
        b.option(
            usize,
            "renderer_debug_text_stack_size",
            "Default renderer debug text stack size",
        ) orelse 1024,
    );

    // SDL extension options.
    const ext_image = b.option(bool, "ext_image", "Enable SDL_image extension") orelse false;
    const ext_net = b.option(bool, "ext_net", "Enable SDL_net extension") orelse false;
    const ext_shadercross = b.option(bool, "ext_shadercross", "Enable SDL_shadercross extension") orelse false;
    const ext_shadercross_dxc = b.option(bool, "ext_shadercross_dxc", "Enable SDL_shadercross extension DXC support") orelse false;
    const ext_ttf = b.option(bool, "ext_ttf", "Enable SDL_ttf extension") orelse false;

    const c_source_code = b.fmt(
        \\#include <SDL3/SDL.h>
        \\{s}
        \\#include <SDL3/SDL_main.h>
        \\#include <SDL3/SDL_vulkan.h>
        \\
        \\{s}
        \\{s}
        \\{s}
        \\{s}
    , .{
        if (!sdl3_main) "#define SDL_MAIN_NOIMPL\n" else "",
        if (ext_image) "#include <SDL3_image/SDL_image.h>\n" else "",
        if (ext_net) "#include <SDL3_net/SDL_net.h>\n" else "",
        if (ext_shadercross) "#include <SDL3_shadercross/SDL_shadercross.h>\n" else "",
        if (ext_ttf) "#include <SDL3_ttf/SDL_ttf.h>\n#include <SDL3_ttf/SDL_textengine.h>\n" else "",
    });

    const c_source_file_step = b.addWriteFiles();
    const c_source_path = c_source_file_step.add("c.c", c_source_code);

    const translate_c = b.addTranslateC(.{
        .root_source_file = c_source_path,
        .target = target,
        .optimize = optimize,
    });
    if (sdl_system_include_path) |val|
        translate_c.addSystemIncludePath(val);

    const c_module = translate_c.createModule();

    const sdl3 = b.addModule("sdl3", .{
        .root_source_file = cfg.root_source_file,
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_module },
        },
    });

    if (sdl_system_include_path) |val|
        sdl3.addSystemIncludePath(val);

    const example_options = ExampleOptions{
        .ext_image = ext_image,
        .ext_net = ext_net,
        .ext_shadercross = ext_shadercross,
        .ext_ttf = ext_ttf,
    };

    sdl3.addOptions("options", options);

    var sdl_dep_lib: ?*std.Build.Step.Compile = null;
    if (system_sdl) {
        sdl3.linkSystemLibrary("sdl3", .{});
        translate_c.linkSystemLibrary("sdl3", .{});
    } else {
        if (b.lazyDependency("sdl", .{
            .target = target,
            .optimize = optimize,
            .preferred_linkage = c_sdl_preferred_linkage,
            .strip = c_sdl_strip,
            .sanitize_c = c_sdl_sanitize_c,
            .lto = c_sdl_lto,
            .emscripten_pthreads = c_sdl_emscripten_pthreads,
            .install_build_config_h = c_sdl_install_build_config_h,
        })) |sdl_dep| {
            const lib = sdl_dep.artifact("SDL3");
            if (sdl_system_include_path) |val|
                lib.root_module.addSystemIncludePath(val);
            b.installArtifact(lib);
            translate_c.addIncludePath(sdl_dep.path("include"));
            sdl3.linkLibrary(lib);
            sdl_dep_lib = lib;
        }
    }

    const ext_linkage = if (system_sdl) .dynamic else c_sdl_preferred_linkage;

    if (ext_image) {
        image.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path);
    }
    if (ext_net) {
        net.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path);
    }
    if (ext_shadercross) {
        shadercross.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path, ext_shadercross_dxc);
    }
    if (ext_ttf) {
        ttf.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, sdl_system_include_path);
    }

    _ = setupDocs(b, sdl3);
    _ = setupTest(b, cfg, options, c_module, system_sdl);

    _ = try setupExamples(b, sdl3, cfg, example_options);
    _ = try runExample(b, sdl3, cfg, example_options);
}

pub fn setupDocs(b: *std.Build, sdl3: *std.Build.Module) *std.Build.Step {
    const sdl3_lib = b.addLibrary(.{
        .root_module = sdl3,
        .name = "sdl3",
    });
    const docs = b.addInstallDirectory(.{
        .source_dir = sdl3_lib.getEmittedDocs(),
        .install_dir = .{ .prefix = {} },
        .install_subdir = "docs",
    });
    const docs_step = b.step("docs", "Generate library documentation");
    docs_step.dependOn(&docs.step);
    return docs_step;
}

pub fn setupExample(
    b: *std.Build,
    sdl3: *std.Build.Module,
    cfg: Config,
    name: []const u8,
) !*std.Build.Step.Compile {
    const exe_module = b.createModule(.{
        .root_source_file = b.path(try std.fmt.allocPrint(b.allocator, "examples/{s}.zig", .{name})),
        .target = cfg.target,
        .optimize = cfg.optimize,
        .imports = &.{
            .{ .name = "sdl3", .module = sdl3 },
        },
    });
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_module,
        .version = cfg.version,
    });
    b.installArtifact(exe);
    return exe;
}

pub fn runExample(b: *std.Build, sdl3: *std.Build.Module, cfg: Config, options: ExampleOptions) !void {
    const run_example: ?[]const u8 = b.option([]const u8, "example", "The example name for running an example") orelse null;
    const run = b.step("run", "Run an example with -Dexample=<example_name> option");
    if (run_example) |example| {
        var can_run = true;
        // TODO unhardcode if we will need more extension-specific examples
        if (std.mem.eql(u8, example, "net")) {
            can_run = options.ext_net;
        }
        if (std.mem.eql(u8, example, "shadercross")) {
            can_run = options.ext_shadercross;
        }
        if (std.mem.eql(u8, example, "ttf")) {
            can_run = options.ext_ttf;
        }

        if (can_run) {
            const run_art = b.addRunArtifact(try setupExample(b, sdl3, cfg, example));
            run_art.step.dependOn(b.getInstallStep());
            run.dependOn(&run_art.step);
        }
    }
}

pub fn setupExamples(
    b: *std.Build,
    sdl3: *std.Build.Module,
    cfg: Config,
    options: ExampleOptions,
) !*std.Build.Step {
    const exp = b.step("examples", "Build all examples");
    var dir = try b.build_root.handle.openDir(b.graph.io, "examples", .{ .iterate = true });
    defer dir.close(b.graph.io);
    var dir_iterator = try dir.walkSelectively(b.allocator);
    defer dir_iterator.deinit();
    while (try dir_iterator.next(b.graph.io)) |file| {
        const name = std.mem.cutSuffix(u8, file.basename, ".zig") orelse continue;
        if (file.kind == .file) {
            var build_example = true;
            // TODO unhardcode if we will need more extension-specific examples
            if (std.mem.eql(u8, name, "net")) {
                build_example = options.ext_net;
            }
            if (std.mem.eql(u8, name, "shadercross")) {
                build_example = options.ext_shadercross;
            }
            if (std.mem.eql(u8, name, "ttf")) {
                build_example = options.ext_ttf;
            }

            if (build_example) {
                _ = try setupExample(b, sdl3, cfg, name);
            }
        }
    }
    exp.dependOn(b.getInstallStep());
    return exp;
}

pub fn setupTest(
    b: *std.Build,
    cfg: Config,
    options: *std.Build.Step.Options,
    c_module: *std.Build.Module,
    system_sdl: bool,
) *std.Build.Step.Compile {
    const test_module = b.createModule(.{
        .root_source_file = cfg.root_source_file,
        .target = cfg.target,
        .optimize = cfg.optimize,
        .imports = &.{
            .{ .name = "c", .module = c_module },
        },
    });
    const tst = b.addTest(.{
        .name = cfg.name,
        .root_module = test_module,
    });
    tst.root_module.addOptions("options", options);
    if (system_sdl) {
        tst.root_module.linkSystemLibrary("sdl3", .{});
    } else if (b.lazyDependency("sdl", .{
        .target = cfg.target,
        .optimize = cfg.optimize,
    })) |sdl_dep| {
        const sdl_dep_lib = sdl_dep.artifact("SDL3");
        tst.root_module.linkLibrary(sdl_dep_lib);
    }
    const tst_run = b.addRunArtifact(tst);
    const tst_step = b.step("test", "Run all tests");
    tst_step.dependOn(&tst_run.step);
    return tst;
}

const Config = struct {
    name: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    root_source_file: std.Build.LazyPath,
    version: std.SemanticVersion,
};
