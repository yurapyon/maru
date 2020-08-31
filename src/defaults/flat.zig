const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");
const content = @import("../content.zig");
const gfx = @import("../gfx.zig");
const math = @import("../math.zig");
const Vec2 = math.Vec2;

//;

pub usingnamespace @import("drawer2d.zig");

//;

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

//;

pub const Spritebatch = struct {
    pub const Sprite = extern struct {
        uv: math.UV_Region = math.UV_Region.init(0., 0., 1., 1.),
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

    instancer: gfx.Instancer(Sprite),
    quad_verts: [4]Vertex2d,
    quad: Mesh2d,
    quad_centered_verts: [4]Vertex2d,
    quad_centered: Mesh2d,

    pub fn init(data: []Sprite) Self {
        var ret: Self = undefined;
        ret.instancer = gfx.Instancer(Sprite).init(data);

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
    ) gfx.BoundInstancer(Sprite, Vertex2d) {
        if (centered) {
            return self.instancer.bind(Vertex2d, &self.quad);
        } else {
            return self.instancer.bind(Vertex2d, &self.quad_centered);
        }
    }
};

//;

pub const Locations2d = struct {
    const Self = @This();

    screen: gfx.Location,
    view: gfx.Location,
    model: gfx.Location,
    time: gfx.Location,
    flip_uvs: gfx.Location,
    tx_diffuse: gfx.Location,
    tx_normal: gfx.Location,
    base_color: gfx.Location,

    pub fn init(program: gfx.Program) Self {
        return .{
            .screen = program.getLocation("_screen"),
            .view = program.getLocation("_view"),
            .model = program.getLocation("_model"),
            .time = program.getLocation("_time"),
            .flip_uvs = program.getLocation("_flip_uvs"),
            .tx_diffuse = program.getLocation("_tx_diffuse"),
            .tx_normal = program.getLocation("_tx_normal"),
            .base_color = program.getLocation("_base_color"),
        };
    }
};

pub const Program2d = struct {
    const Self = @This();

    program: gfx.Program,
    locations: Locations2d,

    // takes ownership of program
    pub fn init(program: gfx.Program) Self {
        return .{
            .program = program,
            .locations = Locations2d.init(program),
        };
    }

    pub fn deinit(self: *Self) void {
        self.program.deinit();
    }

    fn applyEffectToDefaultShader(
        allocator: *Allocator,
        comptime default_shader: []const u8,
        comptime default_effect: []const u8,
        maybe_effect: ?[]const u8,
    ) ![]u8 {
        const ins = std.mem.indexOfScalar(u8, default_shader, '@') orelse unreachable;
        const header = default_shader[0..ins];
        const footer = default_shader[(ins + 1)..];
        const effect = maybe_effect orelse default_effect;
        return std.mem.concat(allocator, u8, &[_][]const u8{ header, effect, footer });
    }

    // TODO write a test that tests default program with no effects works
    pub fn initDefault(
        v_effect: ?[]const u8,
        f_effect: ?[]const u8,
        workspace_allocator: *Allocator,
    ) !Self {
        const v_str = try applyEffectToDefaultShader(
            workspace_allocator,
            content.shaders.default_vert,
            content.shaders.default_vert_effect,
            v_effect,
        );
        defer workspace_allocator.free(v_str);

        const f_str = try applyEffectToDefaultShader(
            workspace_allocator,
            content.shaders.default_frag,
            content.shaders.default_frag_effect,
            f_effect,
        );
        defer workspace_allocator.free(f_str);

        var v_shader = try gfx.Shader.init(c.GL_VERTEX_SHADER, v_str);
        defer v_shader.deinit();
        var f_shader = try gfx.Shader.init(c.GL_FRAGMENT_SHADER, f_str);
        defer f_shader.deinit();

        const prog = try gfx.Program.init(&[_]gfx.Shader{ v_shader, f_shader });

        return Self.init(prog);
    }

    // make is so only way this could fail is if gfx not inited
    //  other things i dont check for that
    //   so maybe just make it so it cant fail
    pub fn initDefaultSpritebatch(
        workspace_allocator: *Allocator,
    ) !Self {
        // TODO do this all at comptime
        const v_str = try applyEffectToDefaultShader(
            workspace_allocator,
            content.shaders.default_vert,
            content.shaders.default_spritebatch_vert,
            null,
        );
        defer workspace_allocator.free(v_str);

        const f_str = try applyEffectToDefaultShader(
            workspace_allocator,
            content.shaders.default_frag,
            content.shaders.default_spritebatch_frag,
            null,
        );
        defer workspace_allocator.free(f_str);

        var v_shader = try gfx.Shader.init(c.GL_VERTEX_SHADER, v_str);
        defer v_shader.deinit();
        var f_shader = try gfx.Shader.init(c.GL_FRAGMENT_SHADER, f_str);
        defer f_shader.deinit();

        const prog = try gfx.Program.init(&[_]gfx.Shader{ v_shader, f_shader });

        return Self.init(prog);
    }
};
