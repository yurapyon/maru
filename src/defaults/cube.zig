// 3d defaults

const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");
const content = @import("../content.zig");

const gfx = @import("../gfx.zig");

const math = @import("../math.zig");
usingnamespace math;

usingnamespace @import("util.zig");

//;

const Vertex3d = extern struct {
    const Self = @This();

    position: Vec3,
    uv: Vec2,
    normal: Vec3,

    pub fn init(position: Vec3, uv: Vec2, normal: Vec3) Self {
        return Self{
            .position = position,
            .uv = uv,
            .normal = normal,
        };
    }

    pub fn setAttributes(vao: *gfx.VertexArray) void {
        var temp = gfx.VertexAttribute{
            .size = 3,
            .ty = c.GL_FLOAT,
            .is_normalized = false,
            .stride = @sizeOf(Self),
            .offset = @byteOffsetOf(Self, "position"),
            .divisor = 0,
        };

        vao.enableAttribute(0, temp);

        temp.offset = @byteOffsetOf(Self, "uv");
        temp.size = 2;
        vao.enableAttribute(1, temp);

        temp.offset = @byteOffsetOf(Self, "normal");
        temp.size = 3;
        vao.enableAttribute(2, temp);
    }
};

pub const Mesh3d = gfx.Mesh(Vertex3d);

pub const Locations3d = struct {
    const Self = @This();

    projection: gfx.Location,
    view: gfx.Location,
    model: gfx.Location,
    time: gfx.Location,
    flip_uvs: gfx.Location,
    tx_diffuse: gfx.Location,
    tx_normal: gfx.Location,
    base_color: gfx.Location,

    pub fn init(program: gfx.Program) Self {
        return .{
            .projection = program.getLocation("_projection"),
            .view = program.getLocation("_view"),
            .model = program.getLocation("_model"),
            .time = program.getLocation("_time"),
            .flip_uvs = program.getLocation("_flip_uvs"),
            .tx_diffuse = program.getLocation("_tx_diffuse"),
            .tx_normal = program.getLocation("_tx_normal"),
            .base_color = program.getLocation("_base_color"),
        };
    }

    // note: doesnt set textures
    pub fn reset(self: Self) void {
        self.projection.setMat4(Mat4.identity());
        self.view.setMat4(Mat4.identity());
        self.model.setMat4(Mat4.identity());
        self.time.setFloat(0.);
        self.flip_uvs.setBool(false);
        self.base_color.setColor(Color.initRgba(1., 1., 1., 1.));
    }
};

pub const Program3d = struct {
    const Self = @This();

    program: gfx.Program,
    locations: Locations3d,

    // takes ownership of program
    pub fn init(program: gfx.Program) Self {
        return .{
            .program = program,
            .locations = Locations3d.init(program),
        };
    }

    pub fn deinit(self: *Self) void {
        self.program.deinit();
    }

    pub fn initDefault(
        workspace_allocator: *Allocator,
        v_effect: ?[]const u8,
        f_effect: ?[]const u8,
    ) !Self {
        const v_str = try applyEffectToDefaultShader(
            workspace_allocator,
            content.shaders.default_3d_vert,
            content.shaders.default_3d_vert_effect,
            v_effect,
        );
        defer workspace_allocator.free(v_str);

        const f_str = try applyEffectToDefaultShader(
            workspace_allocator,
            content.shaders.default_3d_frag,
            content.shaders.default_3d_frag_effect,
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
};
