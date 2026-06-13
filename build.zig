const std = @import("std");
const zig = @import("builtin");

pub const image = @import("build/image.zig");
pub const net = @import("build/net.zig");
pub const shadercross = @import("build/shadercross.zig");
pub const shaders = @import("build/shaders.zig");
pub const ttf = @import("build/ttf.zig");

/// List of example programs to compile from the examples folder.
const examples = [_][]const u8{
    "assert",
    "callbacks",
    "callbacks-main",
    "custom-allocator",
    "dialog",
    "filesystem",
    "hello-world",
    "log",
    "message-box",
    "misc",
    "net",
    "properties",
    "shadercross",
    "storage",
    "tray",
    "ttf",
};

/// Configuration
pub const SdlConfig = struct {
    /// If to use the system's SDL include path.
    sdl_system_include_path: ?std.Build.LazyPath = null,
    /// Link system SDL instead of compiling our own.
    system_sdl: bool = false,
    /// Max stack size available for log messages.
    log_message_stack_size: usize = 1024,
    /// Max stack size available for renderer debug text.
    renderer_debug_text_stack_size: usize = 1024,
    /// If to use a special SDL main instead of a normal main.
    sdl3_main: bool = false,
    /// Enable the image extension.
    ext_image: bool = false,
    /// Enable the networking extension.
    ext_net: bool = false,
    /// Enable the shadercross extension.
    ext_shadercross: bool = false,
    /// Enable DXC support for shadercross.
    ext_shadercross_dxc: bool = false,
    /// Enable the true type font extension.
    ext_ttf: bool = false,
    /// How to link C SDL.
    c_sdl_preferred_linkage: std.builtin.LinkMode = .static,
    /// If to strip C SDL.
    c_sdl_strip: bool = false,
    /// If to sanitize C SDL.
    c_sdl_sanitize_c: std.zig.SanitizeC = .trap,
    /// How to link C SDL.
    c_sdl_lto: std.zig.LtoMode = .none,
    /// If to allow emscripten pthreads for C SDL.
    c_sdl_emscripten_pthreads: bool = false,
    /// Install build config header for C SDL.
    c_sdl_install_build_config_h: bool = false,
};

/// Prepare an SDL3 module.
pub fn prepareSdl(
    b: *std.Build,
    cfg: SdlConfig,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    public: bool,
) *std.Build.Module {
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
        if (!cfg.sdl3_main) "#define SDL_MAIN_NOIMPL\n" else "",
        if (cfg.ext_image) "#include <SDL3_image/SDL_image.h>\n" else "",
        if (cfg.ext_net) "#include <SDL3_net/SDL_net.h>\n" else "",
        if (cfg.ext_shadercross) "#include <SDL3_shadercross/SDL_shadercross.h>\n" else "",
        if (cfg.ext_ttf) "#include <SDL3_ttf/SDL_ttf.h>\n#include <SDL3_ttf/SDL_textengine.h>\n" else "",
    });

    const c_source_file_step = b.addWriteFiles();
    const c_source_path = c_source_file_step.add("c.c", c_source_code);

    const translate_c = b.addTranslateC(.{
        .root_source_file = c_source_path,
        .target = target,
        .optimize = optimize,
    });

    if (cfg.sdl_system_include_path) |val|
        translate_c.addSystemIncludePath(val);

    const c_module = translate_c.createModule();

    const sdl3 = if (public) b.addModule("sdl3", .{
        .root_source_file = b.path("src/sdl3.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_module },
        },
    }) else b.createModule(.{
        .root_source_file = b.path("src/sdl3.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "c", .module = c_module },
        },
    });

    if (cfg.sdl_system_include_path) |val|
        sdl3.addSystemIncludePath(val);

    const options = b.addOptions();
    options.addOption(bool, "main", cfg.sdl3_main);
    options.addOption(
        usize,
        "log_message_stack_size",
        cfg.log_message_stack_size,
    );
    options.addOption(
        usize,
        "renderer_debug_text_stack_size",
        cfg.renderer_debug_text_stack_size,
    );
    sdl3.addOptions("options", options);

    var sdl_dep_lib: ?*std.Build.Step.Compile = null;
    if (cfg.system_sdl) {
        sdl3.linkSystemLibrary("sdl3", .{});
        translate_c.linkSystemLibrary("sdl3", .{});
    } else {
        if (b.lazyDependency("sdl", .{
            .target = target,
            .optimize = optimize,
            .preferred_linkage = cfg.c_sdl_preferred_linkage,
            .strip = cfg.c_sdl_strip,
            .sanitize_c = cfg.c_sdl_sanitize_c,
            .lto = cfg.c_sdl_lto,
            .emscripten_pthreads = cfg.c_sdl_emscripten_pthreads,
            .install_build_config_h = cfg.c_sdl_install_build_config_h,
        })) |sdl_dep| {
            const lib = sdl_dep.artifact("SDL3");
            if (cfg.sdl_system_include_path) |val|
                lib.root_module.addSystemIncludePath(val);
            b.installArtifact(lib);
            translate_c.addIncludePath(sdl_dep.path("include"));
            sdl3.linkLibrary(lib);
            sdl_dep_lib = lib;
        }
    }

    const ext_linkage = if (cfg.system_sdl) .dynamic else cfg.c_sdl_preferred_linkage;

    if (cfg.ext_image) {
        image.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, cfg.sdl_system_include_path);
    }
    if (cfg.ext_net) {
        net.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, cfg.sdl_system_include_path);
    }
    if (cfg.ext_shadercross) {
        shadercross.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, cfg.sdl_system_include_path, cfg.ext_shadercross_dxc);
    }
    if (cfg.ext_ttf) {
        ttf.setup(b, sdl3, translate_c, sdl_dep_lib, ext_linkage, .{
            .optimize = optimize,
            .target = target,
        }, cfg.sdl_system_include_path);
    }

    return sdl3;
}

pub fn build(
    b: *std.Build,
) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // C SDL options.
    const c_sdl_preferred_linkage = b.option(std.builtin.LinkMode, "c_sdl_preferred_linkage", "Prefer building statically or dynamically linked libraries (default: static)") orelse .static;
    const c_sdl_strip = b.option(bool, "c_sdl_strip", "Strip debug symbols (default: varies)") orelse (optimize == .ReleaseSmall);
    const c_sdl_sanitize_c = b.option(std.zig.SanitizeC, "c_sdl_sanitize_c", "Detect C undefined behavior (default: trap)") orelse .trap;
    const c_sdl_lto = b.option(std.zig.LtoMode, "c_sdl_lto", "Perform link time optimization (default: false)") orelse .none;
    const c_sdl_emscripten_pthreads = b.option(bool, "c_sdl_emscripten_pthreads", "Build with pthreads support when targeting Emscripten (default: false)") orelse false;
    const c_sdl_install_build_config_h = b.option(bool, "c_sdl_install_build_config_h", "Additionally install 'SDL_build_config.h' when installing SDL (default: false)") orelse false;
    const sdl_system_include_path = b.option(std.Build.LazyPath, "sdl_system_include_path", "System include path for SDL");
    const sdl_sysroot_path = b.option(std.Build.LazyPath, "sdl_sysroot_path", "System include path for SDL");

    if (sdl_sysroot_path) |val| {
        b.sysroot = val.getPath(b);
    }
    const system_sdl = b.systemIntegrationOption("sdl", .{});

    // SDL options.
    const log_message_stack_size = b.option(usize, "log_message_stack_size", "Default log message stack size") orelse 1024;
    const renderer_debug_text_stack_size = b.option(usize, "renderer_debug_text_stack_size", "Default renderer debug text stack size") orelse 1024;
    const sdl3_main = b.option(bool, "main", "Enable SDL main") orelse false;

    // SDL extension options.
    const ext_image = b.option(bool, "ext_image", "Enable SDL_image extension") orelse false;
    const ext_net = b.option(bool, "ext_net", "Enable SDL_net extension") orelse false;
    const ext_shadercross = b.option(bool, "ext_shadercross", "Enable SDL_shadercross extension") orelse false;
    const ext_shadercross_dxc = b.option(bool, "ext_shadercross_dxc", "Enable SDL_shadercross extension DXC support") orelse false;
    const ext_ttf = b.option(bool, "ext_ttf", "Enable SDL_ttf extension") orelse false;

    var sdl_config = SdlConfig{
        .c_sdl_emscripten_pthreads = c_sdl_emscripten_pthreads,
        .c_sdl_install_build_config_h = c_sdl_install_build_config_h,
        .c_sdl_lto = c_sdl_lto,
        .c_sdl_preferred_linkage = c_sdl_preferred_linkage,
        .c_sdl_sanitize_c = c_sdl_sanitize_c,
        .c_sdl_strip = c_sdl_strip,
        .ext_image = ext_image,
        .ext_net = ext_net,
        .ext_shadercross = ext_shadercross,
        .ext_shadercross_dxc = ext_shadercross_dxc,
        .ext_ttf = ext_ttf,
        .log_message_stack_size = log_message_stack_size,
        .renderer_debug_text_stack_size = renderer_debug_text_stack_size,
        .sdl3_main = sdl3_main,
        .sdl_system_include_path = sdl_system_include_path,
        .system_sdl = system_sdl,
    };
    _ = prepareSdl(b, sdl_config, target, optimize, true);
    sdl_config.ext_image = true;
    sdl_config.ext_net = true;
    sdl_config.ext_shadercross = true;
    sdl_config.ext_ttf = true;
    const sdl3_full = prepareSdl(b, sdl_config, target, optimize, false);

    setupDocs(b, sdl3_full);
    setupExamples(b, sdl3_full, target, optimize);
    setupTest(b, sdl3_full);
}

pub fn setupDocs(
    b: *std.Build,
    sdl3: *std.Build.Module,
) void {
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
}

pub fn setupExample(
    b: *std.Build,
    sdl3: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    examples_step: *std.Build.Step,
) struct { *std.Build.Step.Compile, *std.Build.Step.InstallArtifact } {
    const exe_module = b.createModule(.{
        .root_source_file = b.path(b.fmt("examples/{s}.zig", .{name})),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "sdl3", .module = sdl3 },
        },
    });
    const exe = b.addExecutable(.{
        .name = name,
        .root_module = exe_module,
    });
    const example_install = b.addInstallArtifact(exe, .{});
    examples_step.dependOn(&example_install.step);
    return .{ exe, example_install };
}

pub fn runExample(
    b: *std.Build,
    example_compile: *std.Build.Step.Compile,
    example_install: *std.Build.Step.InstallArtifact,
    run_examples_step: *std.Build.Step,
) void {
    const run_art = b.addRunArtifact(example_compile);
    run_art.step.dependOn(&example_install.step);
    run_examples_step.dependOn(&run_art.step);
}

pub fn setupExamples(
    b: *std.Build,
    sdl3: *std.Build.Module,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) void {
    const examples_step = b.step("examples", "Build all examples");
    const run_example: ?[]const u8 = b.option([]const u8, "example", "The example name for running an example") orelse null;
    const run_examples_step = b.step("run", "Run an example with -Dexample=<example_name> option");

    for (examples) |example| {
        const example_compile, const example_install = setupExample(
            b,
            sdl3,
            target,
            optimize,
            example,
            examples_step,
        );
        if (run_example) |run_example_name| {
            if (std.mem.eql(u8, example, run_example_name)) {
                runExample(b, example_compile, example_install, run_examples_step);
            }
        }
    }
}

pub fn setupTest(
    b: *std.Build,
    sdl3: *std.Build.Module,
) void {
    const tst = b.addTest(.{
        .name = "sdl3",
        .root_module = sdl3,
    });
    const tst_run = b.addRunArtifact(tst);
    const tst_step = b.step("test", "Run all tests");
    tst_step.dependOn(&tst_run.step);
}
