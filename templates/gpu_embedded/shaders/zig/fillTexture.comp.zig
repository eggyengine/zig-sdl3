const std = @import("std");

pub const Image = @SpirvType(.{ .image = .{
    .usage = .{ .storage = f32 },
    .format = .rgba8unorm,
    .dim = .@"2d",
    .depth = .not_depth,
    .arrayed = false,
    .multisampled = false,
    .access = .unknown,
} });

const image = @extern(
    *addrspace(.constant) const Image,
    .{
        .name = "image",
        .decoration = .{
            .descriptor = .{
                .set = 1,
                .binding = 0,
            },
        },
    },
);

export fn main() callconv(.{
    .spirv_kernel = .{
        .x = 8,
        .y = 8,
        .z = 1,
    },
}) void {
    std.spirv.imageWrite(
        image,
        u32,
        .{ std.spirv.global_invocation_id[0], std.spirv.global_invocation_id[1] },
        .{ 1, 1, 0, 1 },
    );
}
