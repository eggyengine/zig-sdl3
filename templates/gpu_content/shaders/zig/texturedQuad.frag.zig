const std = @import("std");

pub const Image = @SpirvType(.{ .image = .{
    .usage = .{ .sampled = f32 },
    .format = .unknown,
    .dim = .@"2d",
    .depth = .not_depth,
    .arrayed = false,
    .multisampled = false,
    .access = .unknown,
} });
pub const SampledImage = @SpirvType(.{ .sampled_image = Image });

const sampled_image = @extern(
    *addrspace(.constant) const SampledImage,
    .{
        .name = "sampled_image",
        .decoration = .{
            .descriptor = .{
                .set = 2,
                .binding = 0,
            },
        },
    },
);

const tex_coord_in = @extern(
    *addrspace(.input) const @Vector(2, f32),
    .{
        .name = "tex_coord",
        .decoration = .{
            .location = 0,
        },
    },
);

const color_out = @extern(
    *addrspace(.output) @Vector(4, f32),
    .{
        .name = "color",
        .decoration = .{
            .location = 0,
        },
    },
);

export fn main() callconv(.{ .spirv_fragment = .{} }) void {
    color_out.* = std.spirv.imageSampleImplicitLod(sampled_image, tex_coord_in.*);
}
