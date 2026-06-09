const std = @import("std");

const position_in = @extern(
    *addrspace(.input) @Vector(3, f32),
    .{
        .name = "position_in",
        .decoration = .{
            .location = 0,
        },
    },
);
const tex_coord_in = @extern(
    *addrspace(.input) @Vector(2, f32),
    .{
        .name = "tex_coord_in",
        .decoration = .{
            .location = 1,
        },
    },
);

const tex_coord_out = @extern(
    *addrspace(.output) @Vector(2, f32),
    .{
        .name = "tex_coord_out",
        .decoration = .{
            .location = 0,
        },
    },
);

export fn main() callconv(.spirv_vertex) void {
    std.gpu.position_out.* = .{ position_in.*[0], position_in.*[1], position_in.*[2], 1 };
    tex_coord_out.* = tex_coord_in.*;
}
