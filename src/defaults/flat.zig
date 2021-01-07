const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");
const content = @import("../content.zig");

const gfx = @import("../gfx.zig");
const Texture = gfx.Texture;
const Image = gfx.Image;
const BoundInstancer = gfx.BoundInstancer;

const CoordinateStack = @import("../coordinates.zig").CoordinateStack;

const math = @import("../math.zig");
usingnamespace math;

//;

// TODO
//   assert spritebatch isnt bound twice from drawer2d
//   floor_positions boolean uniform in default shader?

pub const Vertex2d = extern struct {
    const Self = @This();

    position: Vec2,
    uv: Vec2,

    pub fn init(position: Vec2, uv: Vec2) Self {
        return Self{
            .position = position,
            .uv = uv,
        };
    }

    pub fn genQuad(verts: *[4]Self, centered: bool) void {
        verts[0] = Self.init(Vec2.init(1., 1.), Vec2.init(1., 1.));
        verts[1] = Self.init(Vec2.init(1., 0.), Vec2.init(1., 0.));
        verts[2] = Self.init(Vec2.init(0., 1.), Vec2.init(0., 1.));
        verts[3] = Self.init(Vec2.init(0., 0.), Vec2.init(0., 0.));

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
            v.position = Vec2.init(x, y);
            v.uv = Vec2.init(x + 0.5, y + 0.5);
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
        uv: UV_Region = UV_Region.init(0., 0., 1., 1.),
        transform: Transform2d = Transform2d.identity(),
        color: Color = Color.white(),

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
                @byteOffsetOf(Transform2d, "position");
            vao.enableAttribute(3, temp);

            temp.size = 1;
            temp.offset = @byteOffsetOf(Sprite, "transform") +
                @byteOffsetOf(Transform2d, "rotation");
            vao.enableAttribute(4, temp);

            temp.size = 2;
            temp.offset = @byteOffsetOf(Sprite, "transform") +
                @byteOffsetOf(Transform2d, "scale");
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

    pub fn deinit(self: *Self) void {
        self.quad_centered.deinit();
        self.quad.deinit();
        self.instancer.deinit();
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

    // note: doesnt set textures
    pub fn reset(self: Self) void {
        self.screen.setMat3(Mat3.identity());
        self.view.setMat3(Mat3.identity());
        self.model.setMat3(Mat3.identity());
        self.time.setFloat(0.);
        self.flip_uvs.setBool(false);
        self.base_color.setColor(Color.initRgba(1., 1., 1., 1.));
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

    // TODO move this out somewhere so it can be used for 3d
    fn applyEffectToDefaultShader(
        allocator: *Allocator,
        comptime default_shader: []const u8,
        comptime default_effect: []const u8,
        maybe_effect: ?[]const u8,
    ) ![:0]u8 {
        const ins = std.mem.indexOfScalar(u8, default_shader, '@') orelse unreachable;
        const header = default_shader[0..ins];
        const footer = default_shader[(ins + 1)..];
        const effect = maybe_effect orelse default_effect;
        return std.mem.joinZ(allocator, "", &[_][]const u8{ header, effect, footer });
    }

    // TODO write a test that tests default program with no effects works
    // maybe dont take an allocator param here?
    //   just use a global allocator for 'flat' namespace
    pub fn initDefault(
        workspace_allocator: *Allocator,
        v_effect: ?[]const u8,
        f_effect: ?[]const u8,
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

    pub fn initDefaultSpritebatch(
        workspace_allocator: *Allocator,
        v_effect: ?[]const u8,
        f_effect: ?[]const u8,
    ) !Self {
        return Self.initDefault(
            workspace_allocator,
            v_effect orelse content.shaders.default_spritebatch_vert,
            f_effect orelse content.shaders.default_spritebatch_frag,
        );
    }
};

// drawer2d ===

pub const DrawDefaults = struct {
    const Self = @This();

    program: Program2d,
    spritebatch_program: Program2d,
    white_texture: Texture,
    mahou_texture: Texture,
    ibm_font: FixedFont,

    pub fn init(workspace_allocator: *Allocator) Allocator.Error!Self {
        var white = try Image.init(workspace_allocator, 1, 1);
        white.data[0] = .{
            .r = 255,
            .g = 255,
            .b = 255,
            .a = 255,
        };
        defer white.deinit();

        var mahou = Image.initFromMemory(
            workspace_allocator,
            content.images.mahou,
        ) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => unreachable,
        };
        defer mahou.deinit();

        var codepage437 = gfx.Image.initFromMemory(
            workspace_allocator,
            content.images.codepage437,
        ) catch |err| switch (err) {
            error.OutOfMemory => |e| return e,
            else => unreachable,
        };
        defer codepage437.deinit();

        return DrawDefaults{
            .program = Program2d.initDefault(
                workspace_allocator,
                null,
                null,
            ) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => unreachable,
            },
            .spritebatch_program = Program2d.initDefaultSpritebatch(
                workspace_allocator,
                null,
                null,
            ) catch |err| switch (err) {
                error.OutOfMemory => |e| return e,
                else => unreachable,
            },
            .white_texture = Texture.initImage(white),
            .mahou_texture = Texture.initImage(mahou),
            .ibm_font = FixedFont.init(codepage437, 9, 16),
        };
    }

    pub fn deinit(self: *Self) void {
        self.program.deinit();
        self.spritebatch_program.deinit();
        self.white_texture.deinit();
    }
};

pub const Drawer2d = struct {
    const Self = @This();

    const Settings = struct {
        spritebatch_size: usize,
        circle_resolution: usize,
    };

    // TODO make a separate bindingcontext for spritebatch and shapedrawer
    const BindingContext = struct {
        program: *const Program2d,
        diffuse: *const Texture,
        canvas_width: u32,
        canvas_height: u32,
    };

    allocator: *Allocator,
    coord_stack: CoordinateStack,
    sprite_buffer: []Spritebatch.Sprite,
    sprites: Spritebatch,
    // shapes: ShapeDrawer,

    pub fn init(allocator: *Allocator, settings: Settings) !Self {
        var sprite_buffer = try allocator.alloc(Spritebatch.Sprite, settings.spritebatch_size);
        errdefer allocator.free(sprite_buffer);
        return Self{
            .allocator = allocator,
            .coord_stack = CoordinateStack.init(allocator),
            .sprite_buffer = sprite_buffer,
            .sprites = Spritebatch.init(sprite_buffer),
        };
    }

    pub fn deinit(self: *Self) void {
        self.sprites.deinit();
        self.allocator.free(self.sprite_buffer);
        self.coord_stack.deinit();
    }

    //;

    fn bind(self: *Self, ctx: BindingContext) BoundDrawer2d {
        return .{
            .drawer = self,
            .program = ctx.program,
            .diffuse = ctx.diffuse,
            .canvas_width = ctx.canvas_width,
            .canvas_height = ctx.canvas_height,
        };
    }

    pub fn bindSpritebatch(self: *Self, centered_quad: bool, ctx: BindingContext) BoundSpritebatch {
        var ret = BoundSpritebatch{
            .base = self.bind(ctx),
            .sprites = self.sprites.bind(centered_quad),
            .sprite_transform = Transform2d.identity(),
            .sprite_uv = UV_Region.identity(),
            .sprite_color = Color.white(),
        };
        ret.setProgram(ctx.program);
        ret.setDiffuse(ctx.diffuse);
        return ret;
    }

    // TODO
    pub fn bindShapeDrawer(self: *Self, ctx: BindingContext) BoundShapeDrawer {}
};

const BoundDrawer2d = struct {
    const Self = @This();

    drawer: *Drawer2d,
    program: *const Program2d,
    diffuse: *const Texture,
    canvas_width: u32,
    canvas_height: u32,

    fn setProgram(self: *Self, prog: *const Program2d) void {
        self.program = prog;
        self.program.program.bind();
        self.program.locations.reset();
        self.program.locations.screen.setMat3(Mat3.orthoScreen(UVec2.init(
            self.canvas_width,
            self.canvas_height,
        )));
        self.drawer.coord_stack.clear();
        self.program.locations.view.setMat3(self.drawer.coord_stack.composed);
    }

    fn setDiffuse(self: *Self, tex: *const Texture) void {
        self.diffuse = tex;
        self.program.locations.tx_diffuse.setTextureData(.{
            .select = c.GL_TEXTURE0,
            .bind_to = c.GL_TEXTURE_2D,
            .texture = self.diffuse,
        });
    }

    fn pushCoord(self: *Self, t: CoordinateStack.Transform) Allocator.Error!void {
        try self.drawer.coord_stack.push(t);
        self.program.locations.view.setMat3(self.drawer.coord_stack.composed);
    }

    fn popCoord(self: *Self) CoordinateStack.Error!void {
        try self.drawer.coord_stack.pop();
        self.program.locations.view.setMat3(self.drawer.coord_stack.composed);
    }

    fn clearCoords(self: *Self) void {
        self.drawer.coord_stack.clear();
        self.program.locations.view.setMat3(self.drawer.coord_stack.composed);
    }
};

pub const BoundSpritebatch = struct {
    const Self = @This();

    base: BoundDrawer2d,
    sprites: BoundInstancer(Spritebatch.Sprite, Vertex2d),
    sprite_transform: Transform2d,
    sprite_uv: UV_Region,
    sprite_color: Color,

    //;

    pub fn setProgram(self: *Self, prog: *const Program2d) void {
        if (prog != self.base.program) {
            self.drawNow();
        }
        self.base.setProgram(prog);
    }

    pub fn setDiffuse(self: *Self, tex: *const Texture) void {
        if (tex != self.base.diffuse) {
            self.drawNow();
        }
        self.base.setDiffuse(tex);
    }

    pub fn pushCoord(self: *Self, t: CoordinateStack.Transform) Allocator.Error!void {
        self.drawNow();
        try self.base.pushCoord(t);
    }

    pub fn popCoord(self: *Self) CoordinateStack.Error!void {
        self.drawNow();
        try self.base.popCoord();
    }

    pub fn clearCoords(self: *Self) void {
        self.drawNow();
        self.base.clearCoords();
    }

    //;

    pub fn unbind(self: *Self) void {
        self.sprites.unbind();
    }

    pub fn drawNow(self: *Self) void {
        self.sprites.draw();
    }

    pub fn rectangle(self: *Self, x1: f32, y1: f32, x2: f32, y2: f32) void {
        var sp = self.sprites.pull();
        sp.transform.position.x = x1;
        sp.transform.position.y = y1;
        sp.transform.rotation = 0.;
        sp.transform.scale.x = x2 - x1;
        sp.transform.scale.y = y2 - y1;
        sp.uv = self.sprite_uv;
        sp.color = self.sprite_color;
    }

    pub fn sprite(self: *Self, transform: Transform2d, uv: UV_Region, color: Color) void {
        var sp = self.sprites.pull();
        sp.transform = transform;
        sp.uv = uv;
        sp.color = color;
    }

    pub fn print(self: *Self, font: FixedFont, text: []const u8) void {
        self.setDiffuse(&font.texture);
        const fw = @intToFloat(f32, font.glyph_width);
        const fh = @intToFloat(f32, font.glyph_height);
        var x_at: f32 = 0.;
        var y_at: f32 = 0.;
        for (text) |ch| {
            var sp = self.sprites.pull();
            sp.transform.position.x = x_at;
            sp.transform.position.y = y_at;
            sp.transform.rotation = 0.;
            sp.transform.scale.x = fw;
            sp.transform.scale.y = fh;
            sp.uv = font.uvRegion(ch);
            sp.color = self.sprite_color;

            x_at += fw;
        }
    }
};

pub const BoundShapeDrawer = struct {
    const Self = @This();

    base: BoundDrawer2d,

    //;

    pub fn setProgram() void {
        //;
    }

    pub fn setTexture() void {
        //;
    }

    pub fn pushCoord() void {
        //;
    }

    pub fn popCoord() void {
        //;
    }

    //;
};

// fonts ===

// Codepage 437 font
pub const FixedFont = struct {
    const Self = @This();

    texture: Texture,
    glyph_width: u32,
    glyph_height: u32,
    width_ct: u32,
    height_ct: u32,

    pub fn init(image: Image, glyph_width: u32, glyph_height: u32) Self {
        var tex = Texture.initImage(image);
        tex.setFilter(c.GL_NEAREST, c.GL_NEAREST);
        return .{
            .texture = tex,
            .glyph_width = glyph_width,
            .glyph_height = glyph_height,
            .width_ct = image.width / glyph_width,
            .height_ct = image.height / glyph_height,
        };
    }

    pub fn deinit(self: *Self) void {
        self.texture.deinit();
    }

    //;

    pub fn region(self: Self, glyph: u8) TextureRegion {
        // glyph is a number betw 0 and 255
        // wrap it around width_ct
        const x = glyph % self.width_ct;
        const y = glyph / self.width_ct;
        return TextureRegion.init(
            @intCast(i32, x * self.glyph_width),
            @intCast(i32, y * self.glyph_height),
            @intCast(i32, (x + 1) * self.glyph_width),
            @intCast(i32, (y + 1) * self.glyph_height),
        );
    }

    pub fn uvRegion(self: Self, glyph: u8) UV_Region {
        const tx = self.region(glyph);
        return tx.normalized(IVec2.init(
            @intCast(i32, self.texture.width),
            @intCast(i32, self.texture.height),
        ));
    }
};
