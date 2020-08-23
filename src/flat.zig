const std = @import("std");

const c = @import("c.zig");
const gfx = @import("gfx.zig");
const math = @import("math.zig");
const Vec2 = math.Vec2;

pub const Vertex2d = struct {
    const Self = @This();

    position: Vec2(f32),
    uv: Vec2(f32),

    pub fn init(position: Vec2(f32), uv: Vec2(f32)) Self {
        return Self{
            .position = position,
            .uv = uv,
        };
    }

    pub fn genQuad(verts: *[4]Self, centered: bool) void {
        verts[0] = Self.init(Vec2(f32).init(1., 1.), Vec2(f32).init(1., 1.));
        verts[1] = Self.init(Vec2(f32).init(1., 0.), Vec2(f32).init(1., 0.));
        verts[2] = Self.init(Vec2(f32).init(0., 1.), Vec2(f32).init(0., 1.));
        verts[3] = Self.init(Vec2(f32).init(0., 0.), Vec2(f32).init(0., 0.));

        if (centered) {
            for (verts) |*v| {
                v.position.x -= 0.5;
                v.position.y -= 0.5;
            }
        }
    }

    pub fn genCircle(verts: []Self) void {
        const angle_step = std.math.tau / @intToFloat(f32, verts.len);
        for (verts) |*v, i| {
            const at = @intToFloat(f32, i) * angle_step;
            const x = std.math.cos(at) / 2.;
            const y = std.math.sin(at) / 2.;
            v.position = Vec2(f32).init(x, y);
            v.uv = Vec2(f32).init(x + 0.5, y + 0.5);
        }
    }

    pub fn setAttributes(vao: *gfx.VertexArray) void {
        var temp = gfx.VertexAttribute{
            .size = 2,
            .ty = c.GL_FLOAT,
            .is_normalized = false,
            .stride = @sizeOf(Self),
            .offset = @byteOffsetOf(Self, "position"),
            .divisor = 0,
        };

        vao.enableAttribute(0, temp);
        temp.offset = @byteOffsetOf(Self, "uv");
        vao.enableAttribute(1, temp);
    }
};

pub const Mesh2d = gfx.Mesh(Vertex2d);
