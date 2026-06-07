const gpu = @import("../gpu.zig");
const log = @import("../log.zig");
const std = @import("std");

/// Metadata for graphics shaders.
pub const GraphicsShaderMetadata = @import("gpu/GraphicsShaderMetadata.zig");

/// An error with shader compatibility.
pub const CompatibilityError = error{
    /// There are some fragment shader inputs with no output from the vertex shader.
    FragmentShaderInputNotSatisfied,
    /// The types between the vertex and fragment shader are not compatible.
    TypesMismatch,
};

/// Error encountered when loading a shader.
pub const LoadError = error{
    /// Unable to load a shader format.
    UnsupportedFormat,
};

/// Ensure a vertex and fragment shader are compatible.
///
/// ## Function Parameters
/// * `vertex_shader_metadata`: The metadata for the vertex shader.
/// * `fragment_shader_metadata`: The metadata for the fragment shader.
pub fn ensureCompatibleGraphicsShaders(
    vertex_shader_metadata: GraphicsShaderMetadata,
    fragment_shader_metadata: GraphicsShaderMetadata,
) !void {
    outer: for (fragment_shader_metadata.inputs) |input| {
        for (vertex_shader_metadata.outputs) |output| {
            if (output.location == input.location) {
                if (output.type != input.type) {
                    try log.Category.gpu.logError("Fragment shader input \"{s}\" with type \"{s}\" and vertex shader output \"{s}\" with type \"{s}\" at location {d} have mismatching types", .{
                        input.name,
                        @tagName(input.type),
                        output.name,
                        @tagName(output.type),
                        input.location,
                    });
                    return error.TypesMismatch;
                }
                continue :outer;
            }
        } else {
            try log.Category.gpu.logError("Fragment shader input \"{s}\" at location {d} has no corresponding vertex shader output", .{ input.name, input.location });
            return error.FragmentShaderInputNotSatisfied;
        }
    }
}

/// Ensure a vertex and fragment shader are compatible at comptime.
///
/// ## Function Parameters
/// * `vertex_shader_metadata`: The metadata for the vertex shader.
/// * `fragment_shader_metadata`: The metadata for the fragment shader.
pub inline fn ensureCompatibleGraphicsShadersComptime(
    comptime vertex_shader_metadata: GraphicsShaderMetadata,
    comptime fragment_shader_metadata: GraphicsShaderMetadata,
) void {
    outer: inline for (fragment_shader_metadata.inputs) |input| {
        inline for (vertex_shader_metadata.outputs) |output| {
            if (output.location == input.location) {
                if (output.type != input.type) {
                    @compileError(std.fmt.comptimePrint("Fragment shader input \"{s}\" with type \"{s}\" and vertex shader output \"{s}\" with type \"{s}\" at location {d} have mismatching types", .{
                        input.name,
                        @tagName(input.type),
                        output.name,
                        @tagName(output.type),
                        input.location,
                    }));
                }
                continue :outer;
            }
        } else {
            @compileError(std.fmt.comptimePrint("Fragment shader input \"{s}\" at location {d} has no corresponding vertex shader output", .{ input.name, input.location }));
        }
    }
}

/// Get the graphics shader metadata at compile time
///
/// ## Function Parameters
/// * `shader`: The embedded shader to load.
///
/// ## Return Value
/// Returns the graphics shader metadata.
pub fn getGraphicsShaderMetadata(
    shader: anytype,
) GraphicsShaderMetadata {
    const metadata = shader.zon.data;
    var inputs: [metadata.inputs.len]GraphicsShaderMetadata.Var = undefined;
    var outputs: [metadata.outputs.len]GraphicsShaderMetadata.Var = undefined;
    inline for (0..inputs.len) |ind| {
        inputs[ind] = .{
            .name = metadata.inputs[ind].name,
            .type = metadata.inputs[ind].type,
            .location = metadata.inputs[ind].location,
        };
    }
    inline for (0..outputs.len) |ind| {
        outputs[ind] = .{
            .name = metadata.outputs[ind].name,
            .type = metadata.outputs[ind].type,
            .location = metadata.outputs[ind].location,
        };
    }
    return GraphicsShaderMetadata{
        .inputs = &inputs,
        .outputs = &outputs,
        .samplers = metadata.samplers,
        .storage_buffers = metadata.storage_buffers,
        .storage_textures = metadata.storage_textures,
        .uniform_buffers = metadata.uniform_buffers,
    };
}

/// Load an embedded graphics shader and use its metadata (will error if not exists).
///
/// ## Function Parameters
/// * `device`: The GPU device.
/// * `shader`: The embedded shader to load.
///
/// ## Return Value
/// Returns the loaded graphics shader.
pub fn loadGraphicsShaderEmbeddedWithMetadata(
    device: gpu.Device,
    shader: anytype,
) !gpu.Shader {
    const supported_formats = device.getShaderFormats();
    const shader_metadata = getGraphicsShaderMetadata(shader);
    inline for (@typeInfo(gpu.ShaderFormatFlags).@"struct".fields) |field| {
        if (@hasDecl(shader, field.name) and @field(supported_formats, field.name)) {
            var created_format = gpu.ShaderFormatFlags{};
            @field(created_format, field.name) = true;
            return try device.createShader(.{
                .code = @field(shader, field.name).data,
                .entry_point = shader.entry_point,
                .format = created_format,
                .stage = std.meta.stringToEnum(gpu.ShaderStage, shader.stage).?,
                .num_samplers = shader_metadata.samplers,
                .num_storage_textures = shader_metadata.storage_textures,
                .num_storage_buffers = shader_metadata.storage_buffers,
                .num_uniform_buffers = shader_metadata.uniform_buffers,
                .props = .{ .name = shader.name },
            });
        }
    }
    try log.Category.gpu.logError("Unable to load shader for graphics format {any}", .{supported_formats});
    return error.UnsupportedFormat;
}

test "extras gpu" {
    std.testing.refAllDecls(@This());
}
