const std = @import("std");

const color_in = @extern(
    *addrspace(.input) @Vector(4, f32),
    .{
        .name = "color_in",
        .decoration = .{
            .location = 0,
        },
    },
);

const color_out = @extern(
    *addrspace(.output) @Vector(4, f32),
    .{
        .name = "color_out",
        .decoration = .{
            .location = 0,
        },
    },
);

export fn main() callconv(.spirv_fragment) void {
    color_out.* = color_in.*;
}
