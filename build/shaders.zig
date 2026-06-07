const std = @import("std");

/// Arguments for compiling HLSL.
pub const CompileHlslArgs = struct {
    /// The shadercross executable.
    shadercross: *std.Build.Step.Compile,
    /// The input to compile with shadercross.
    input: std.Build.LazyPath,
    /// The shader stage.
    stage: ShadercrossStage,
    /// The name of the shader entry point, otherwise "main".
    entrypoint: ?[]const u8 = null,
    /// The directory for HLSL inclusion, if any.
    hlsl_include_directory: ?std.Build.LazyPath = null,
    /// The definitions for HLSL files, if any.
    hlsl_defines: []const HlslDefine = &.{},
    /// The version of MSL to use, otherwise `1.2.0`.
    msl_version: ?[]const u8 = null,
    /// Generate debug information if possible.
    debug: bool = false,
    /// Program to convert JSON to ZON if ZON is specified, can be `null` if not needed.
    shader_metadata2zon: ?*std.Build.Step.Compile = null,
};

/// An HLSL define.
pub const HlslDefine = struct {
    /// Name of the variable to define.
    name: []const u8,
    /// Value to define for the variable, if any.
    value: ?[]const u8,
};

/// A collection of shader files for the backend.
pub const ShaderFiles = struct {
    /// The base output name.
    base_name: []const u8,
    /// Entry point of the shader.
    entry_point: []const u8,
    /// Stage of the shader.
    stage: []const u8,
    /// The files to potentially write.
    files: std.EnumMap(ShadercrossFormat, ShaderMetadata),

    /// Add the zig source file for the shader file.
    ///
    /// ## Function Parameters
    /// * `self`: The shader files.
    /// * `b`: The build system.
    /// * `module`: The module to add the source to.
    /// * `write_files`: A write files step to write files with.
    pub fn addSource(
        self: *ShaderFiles,
        b: *std.Build,
        module: *std.Build.Module,
        write_files: *std.Build.Step.WriteFile,
    ) !void {
        var writer = std.Io.Writer.Allocating.init(b.allocator);
        defer writer.deinit();

        // Other metadata.
        try writer.writer.print("pub const entry_point: [:0]const u8 = \"{s}\";\n", .{self.entry_point});
        try writer.writer.print("pub const stage = \"{s}\";\n", .{self.stage});
        try writer.writer.print("pub const name = \"{s}\";\n", .{self.base_name});

        // Write each source.
        var file_iter = self.files.iterator();
        while (file_iter.next()) |file|
            try writer.writer.print("pub const {s} = @import(\"{s}.zig\");\n", .{ @tagName(file.key), file.value.name });
        const zig_shim = b.createModule(.{ .root_source_file = write_files.add(b.fmt("{s}.zig", .{self.base_name}), try writer.toOwnedSlice()) });
        file_iter = self.files.iterator();
        while (file_iter.next()) |file|
            file.value.addSource(b, zig_shim, write_files, file.key != .zon);
        module.addImport(b.fmt("{s}.zig", .{self.base_name}), zig_shim);
    }
};

/// Shader metadata for a generated shader.
pub const ShaderMetadata = struct {
    /// Name of the shader output.
    name: []const u8,
    /// Shader data.
    data: std.Build.LazyPath,

    /// Add a zig source file for the metadata.
    ///
    /// ## Function Parameters
    /// * `self`: The shader metadata to add.
    /// * `b`: The build system.
    /// * `module`: The module to add the source imports to.
    /// * `write_files`: A write files build step to use to write data to for the import.
    /// * `embed`: If to embed the file or import it, typically only for ZON.
    pub fn addSource(
        self: ShaderMetadata,
        b: *std.Build,
        module: *std.Build.Module,
        write_files: *std.Build.Step.WriteFile,
        embed: bool,
    ) void {
        const zig_shim = b.createModule(.{
            .root_source_file = write_files.add(
                b.fmt("{s}.zig", .{self.name}),
                b.fmt("pub const name = \"{s}\";\npub const data = {s}(\"{s}\");\n", .{ self.name, if (embed) "@embedFile" else "@import", self.name }),
            ),
        });
        zig_shim.addAnonymousImport(self.name, .{ .root_source_file = self.data });
        module.addImport(b.fmt("{s}.zig", .{self.name}), zig_shim);
    }
};

/// Output format for SDL shadercross.
pub const ShadercrossFormat = enum {
    dxbc,
    dxil,
    msl,
    spirv,
    hlsl,
    json,
    zon,
};

/// Arguments for shadercross.
pub const ShadercrossArgs = struct {
    /// The shadercross executable.
    shadercross: *std.Build.Step.Compile,
    /// The input to compile with shadercross.
    input: std.Build.LazyPath,
    /// The source format of the input.
    source: ShadercrossSource,
    /// The shader stage.
    stage: ShadercrossStage,
    /// The name of the shader entry point, otherwise "main".
    entrypoint: ?[]const u8 = null,
    /// The directory for HLSL inclusion, if any.
    hlsl_include_directory: ?std.Build.LazyPath = null,
    /// The definitions for HLSL files, if any.
    hlsl_defines: []const HlslDefine = &.{},
    /// The version of MSL to use, otherwise `1.2.0`.
    msl_version: ?[]const u8 = null,
    /// Generate debug information if possible.
    debug: bool = false,
    /// Generate PSSL-compatible shader, destination format should be HLSL.
    pssl: bool = false,
    /// Program to convert JSON to ZON if ZON is specified, can be `null` if not needed.
    shader_metadata2zon: ?*std.Build.Step.Compile = null,
};

/// The source language format.
pub const ShadercrossSource = enum {
    spirv,
    hlsl,
};

/// The shader stage.
pub const ShadercrossStage = enum {
    vertex,
    fragment,
    compute,
};

/// Compile an HLSL file using shadercross.
///
/// ## Function Parameters
/// * `b`: The build system.
/// * `args`: HLSL compilation arguments.
/// * `dest`: The destination format to compile to.
/// * `output_name`: Output name of the file to compile to.
///
/// ## Return Value
/// Returns the compiled HLSL file path.
pub fn compileHlsl(
    b: *std.Build,
    args: CompileHlslArgs,
    dest: ?ShadercrossFormat,
    output_name: []const u8,
) std.Build.LazyPath {
    return runShadercross(
        b,
        .{
            .shadercross = args.shadercross,
            .input = args.input,
            .source = .hlsl,
            .stage = args.stage,
            .entrypoint = args.entrypoint,
            .hlsl_include_directory = args.hlsl_include_directory,
            .hlsl_defines = args.hlsl_defines,
            .msl_version = args.msl_version,
            .debug = args.debug,
            .pssl = false,
            .shader_metadata2zon = args.shader_metadata2zon,
        },
        dest,
        output_name,
    );
}

/// Compile an HLSL file using shadercross.
///
/// ## Function Parameters
/// * `b`: The build system.
/// * `args`: HLSL compilation arguments.
/// * `destination_formats`: The destination formats to generate for the outputs.
/// * `output_base_name`: The base name to use for the output before the `.format_extension` is added to the end.
/// * `write_files`: Write files step in case a copy is just needed.
/// * `output_name`: Output name of the file to compile to.
///
/// ## Return Value
/// Returns the compiled formats.
pub fn compileHlslForFormats(
    b: *std.Build,
    args: CompileHlslArgs,
    destination_formats: std.EnumSet(ShadercrossFormat),
    output_base_name: []const u8,
    write_files: *std.Build.Step.WriteFile,
) ShaderFiles {
    return runShadercrossForFormats(
        b,
        .{
            .shadercross = args.shadercross,
            .input = args.input,
            .source = .hlsl,
            .stage = args.stage,
            .entrypoint = args.entrypoint,
            .hlsl_include_directory = args.hlsl_include_directory,
            .hlsl_defines = args.hlsl_defines,
            .msl_version = args.msl_version,
            .debug = args.debug,
            .pssl = false,
            .shader_metadata2zon = args.shader_metadata2zon,
        },
        destination_formats,
        output_base_name,
        write_files,
    );
}

/// Compile the shader metadata to zon program.
///
/// ## Function Parameters
/// * `b`: The build system of SDL3.
///
/// ## Return Value
/// Returns the executable.
pub fn compileShaderMetadata2Zon(
    b: *std.Build,
) *std.Build.Step.Compile {
    const exe = b.addExecutable(
        .{
            .name = "shader-metadata2zon",
            .root_module = b.createModule(
                .{
                    .root_source_file = b.path("build/tools/shader_metadata2zon.zig"),
                    .target = b.graph.host,
                    .optimize = .ReleaseFast,
                },
            ),
        },
    );
    exe.root_module.addAnonymousImport("GraphicsShaderMetadata", .{
        .root_source_file = b.path("src/extras/gpu/GraphicsShaderMetadata.zig"),
    });
    return exe;
}

/// Run SDL shadercross.
///
/// ## Function Parameters
/// * `b`: The build system.
/// * `args`: Shadercross arguments.
/// * `dest`: The destination format of the output, otherwise deduce from the file name.
/// * `output_name`: The output name of the file.
///
/// ## Return Value
/// Returns the output path.
pub fn runShadercross(
    b: *std.Build,
    args: ShadercrossArgs,
    dest: ?ShadercrossFormat,
    output_name: []const u8,
) std.Build.LazyPath {
    const run = b.addRunArtifact(args.shadercross);
    run.addFileArg(args.input);
    run.addArg("--source");
    run.addArg(switch (args.source) {
        .hlsl => "HLSL",
        .spirv => "SPIRV",
    });
    if (dest) |val| {
        run.addArg("--dest");
        run.addArg(switch (val) {
            .dxbc => "DXBC",
            .dxil => "DXIL",
            .hlsl => "HLSL",
            .json, .zon => "JSON",
            .msl => "MSL",
            .spirv => "SPIRV",
        });
    }
    run.addArg("--stage");
    run.addArg(@tagName(args.stage));
    if (args.entrypoint) |val| {
        run.addArg("--entrypoint");
        run.addArg(val);
    }
    run.addArg("--output");
    const ret = run.addOutputFileArg(if (dest != .zon) output_name else b.fmt("{s}.json", .{output_name}));
    if (args.hlsl_include_directory) |val| {
        run.addArg("--include");
        run.addDirectoryArg(val);
    }
    for (args.hlsl_defines) |define| {
        if (define.value) |val| {
            run.addArg(b.fmt("-D{s}={s}", .{ define.name, val }));
        } else {
            run.addArg(b.fmt("-D{s}", .{define.name}));
        }
    }
    if (args.msl_version) |val| {
        run.addArg("--msl-version");
        run.addArg(val);
    }
    if (args.debug)
        run.addArg("--debug");
    if (args.pssl)
        run.addArg("-pssl");
    return if (dest != .zon) ret else runShaderMetadata2Zon(b, args.shader_metadata2zon.?, args.stage != .compute, ret, output_name);
}

/// Run SDL shadercross to generate multiple output formats.
///
/// ## Function Parameters
/// * `b`: The build system.
/// * `args`: Shadercross arguments.
/// * `destination_formats`: The destination formats to generate for the outputs.
/// * `output_base_name`: The base name to use for the output before the `.format_extension` is added to the end.
/// * `write_files`: Write files step in case a copy is just needed.
///
/// ## Return Value
/// Returns the shader files.
pub fn runShadercrossForFormats(
    b: *std.Build,
    args: ShadercrossArgs,
    destination_formats: std.EnumSet(ShadercrossFormat),
    output_base_name: []const u8,
    write_files: *std.Build.Step.WriteFile,
) ShaderFiles {
    var ret: ShaderFiles = .{
        .base_name = output_base_name,
        .entry_point = args.entrypoint orelse "main",
        .stage = @tagName(args.stage),
        .files = .init(.{}),
    };
    var format_iter = destination_formats.iterator();
    while (format_iter.next()) |format| {
        const name = b.fmt("{s}.{s}", .{ output_base_name, @tagName(format) });
        ret.files.put(format, .{
            .name = name,
            .data = if ((format == .spirv and args.source == .spirv) or (format == .hlsl and args.source == .hlsl)) write_files.addCopyFile(args.input, name) else runShadercross(
                b,
                args,
                format,
                name,
            ),
        });
    }
    return ret;
}

/// Run the shader metadata to zon program.
///
/// ## Function Parameters
/// * `b`: The build system.
/// * `shader_metadata2zon`: Executable to convert shader metadata JSON to zon.
/// * `graphics`: If the data is graphics or compute.
/// * `input_file`: Input file path.
/// * `output_base_name`: Base name of the output file.
///
/// ## Return Value
/// Returns the output ZON file.
pub fn runShaderMetadata2Zon(
    b: *std.Build,
    shader_metadata2zon: *std.Build.Step.Compile,
    graphics: bool,
    input_file: std.Build.LazyPath,
    output_base_name: []const u8,
) std.Build.LazyPath {
    const run = b.addRunArtifact(shader_metadata2zon);
    run.addArg(if (graphics) "-g" else "-c");
    run.addFileArg(input_file);
    return run.addOutputFileArg(output_base_name);
}
