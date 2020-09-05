const std = @import("std");
const Allocator = std.mem.Allocator;

const c = @import("../c.zig");

const gfx = @import("../gfx.zig");
const Texture = gfx.Texture;
const Image = gfx.Image;
const BoundInstancer = gfx.BoundInstancer;

const CoordinateStack = @import("../coordinates.zig").CoordinateStack;
usingnamespace @import("flat.zig");
usingnamespace @import("../math.zig");

//;

pub const DrawDefaults = struct {
    const Self = @This();

    program: Program2d,
    spritebatch_program: Program2d,
    white_texture: Texture,

    pub fn init(workspace_allocator: *Allocator) !Self {
        var img = try Image.init(workspace_allocator, 1, 1);
        img.data[0] = .{
            .r = 255,
            .g = 255,
            .b = 255,
            .a = 255,
        };
        defer img.deinit();
        return DrawDefaults{
            .program = try Program2d.initDefault(
                null,
                null,
                workspace_allocator,
            ),
            .spritebatch_program = try Program2d.initDefaultSpritebatch(
                workspace_allocator,
            ),
            .white_texture = Texture.init(img),
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
        coord_stack_size: usize,
        spritebatch_size: usize,
        circle_resolution: usize,
    };

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
            .coord_stack = try CoordinateStack.initCapacity(allocator, settings.coord_stack_size),
            .sprite_buffer = sprite_buffer,
            .sprites = Spritebatch.init(sprite_buffer),
        };
    }

    pub fn deinit(self: *Self) void {
        self.sprites.deinit();
        self.allocator.free(self.sprite_buffer);
        self.coord_stack.deinit();
    }

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
        self.program.locations.screen.setMat3(Mat3.orthoScreen(Vec2(u32).init(
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

    // TODO handle errors
    fn pushCoord(self: *Self, t: CoordinateStack.Transform) void {
        self.drawer.coord_stack.push(t);
        self.program.locations.view.setMat2(self.drawer.coord_stack.composed);
    }

    fn popCoord(self: *Self) void {
        self.drawer.coord_stack.pop();
        self.program.locations.view.setMat2(self.drawer.coord_stack.composed);
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

    pub fn pushCoord(self: *Self, t: CoordinateStack.Transform) void {
        self.drawNow();
        self.base.pushCoord(t);
    }

    pub fn popCoord(self: *Self) void {
        self.drawNow();
        self.base.popCoord();
    }

    //;

    pub fn deinit(self: *Self) void {
        self.sprites.deinit();
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
        sp.transform = transfrom;
        sp.uv = uv;
        sp.color = color;
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
