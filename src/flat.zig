const std = @import("std");

const c = @import("c.zig");
const gfx = @import("gfx.zig");
const math = @import("math.zig");
const Vec2 = math.Vec2;

pub const Vertex2d = extern struct {
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

pub const Spritebatch = struct {
    pub const Sprite = extern struct {
        uv: math.UvRegion = math.UvRegion.init(0., 0., 1., 1.),
        transform: math.Transform2d = math.Transform2d.identity(),
        color: math.Color = math.Color.white(),

        pub fn setAttributes(vao: gfx.VertexArray) void {
            var temp = gfx.VertexAttribute{
                .size = 4,
                .ty = c.GL_FLOAT,
                .is_normalized = false,
                .stride = @sizeOf(Sprite),
                .offset = @byteOffsetOf(Sprite, "uv"),
                .divisor = 1,
            };

            vao.enableAttribute(2, temp);

            temp.size = 2;
            temp.offset = @byteOffsetOf(Sprite, "transform") +
                @byteOffsetOf(math.Transform2d, "position");
            vao.enableAttribute(3, temp);

            temp.size = 1;
            temp.offset = @byteOffsetOf(Sprite, "transform") +
                @byteOffsetOf(math.Transform2d, "rotation");
            vao.enableAttribute(4, temp);

            temp.size = 2;
            temp.offset = @byteOffsetOf(Sprite, "transform") +
                @byteOffsetOf(math.Transform2d, "scale");
            vao.enableAttribute(5, temp);

            temp.size = 4;
            temp.offset = @byteOffsetOf(Sprite, "color");
            vao.enableAttribute(6, temp);
        }
    };

    const Self = @This();
    const Mesh = gfx.Mesh;
    const Instancer = gfx.Instancer;
    const BoundInstancer = gfx.BoundInstancer;

    instancer: Instancer(Sprite),
    quad_verts: [4]Vertex2d,
    quad: Mesh2d,
    quad_centered_verts: [4]Vertex2d,
    quad_centered: Mesh2d,

    pub fn init(data: []Sprite) Self {
        var ret: Self = undefined;
        ret.instancer = Instancer(Sprite).init(data);

        Vertex2d.genQuad(&ret.quad_verts, false);
        ret.quad = Mesh2d.init(
            &ret.quad_verts,
            &[_]u32{},
            c.GL_STATIC_DRAW,
            c.GL_TRIANGLE_STRIP,
        );
        ret.instancer.makeVertexArrayCompatible(ret.quad.vao);

        Vertex2d.genQuad(&ret.quad_centered_verts, false);
        ret.quad_centered = Mesh2d.init(
            &ret.quad_centered_verts,
            &[_]u32{},
            c.GL_STATIC_DRAW,
            c.GL_TRIANGLE_STRIP,
        );
        ret.instancer.makeVertexArrayCompatible(ret.quad_centered.vao);

        return ret;
    }

    pub fn bind(
        self: *Self,
        centered: bool,
    ) BoundInstancer(Sprite, Vertex2d) {
        if (centered) {
            return self.instancer.bind(Vertex2d, &self.quad);
        } else {
            return self.instancer.bind(Vertex2d, &self.quad_centered);
        }
    }
};
