const std = @import("std");
const nitori = @import("nitori");

pub const c = @import("c.zig");
pub const gfx = @import("gfx.zig");
pub const flat = @import("flat.zig");
pub const math = @import("math.zig");
pub const states = @import("states.zig");

//;

// test "state machine" {
//     const GlobalData = struct {};
//
//     const StateMachine = states.StateMachine(GlobalData);
//
//     const A = struct {
//         state: StateMachine.State = .{
//             .start = start,
//             .stop = stop,
//         },
//
//         fn init() @This() {
//             return .{};
//         }
//
//         fn deinit() void {}
//
//         fn start(state: *StateMachine.State, ctx: GlobalData) void {}
//
//         fn stop(state: *StateMachine.State, ctx: GlobalData) void {
//             var self = @fieldParentPtr(A, "state", state);
//             self.deinit();
//         }
//     };
//
//     const a = A.init();
// }

test "vert2d" {
    var arr: [4]flat.Vertex2d = undefined;
    flat.Vertex2d.genQuad(&arr, false);

    var circle: [100]flat.Vertex2d = undefined;
    flat.Vertex2d.genCircle(&circle);

    var iter = nitori.ChunkIterator(flat.Vertex2d).init(&circle, 10);
    while (iter.next()) |chunk| {
        std.log.warn("{}\n", .{chunk});
    }
}

test "gfx main" {
    const alloc = std.testing.allocator;

    const ctx = try gfx.Context.init(.{
        .window_width = 800,
        .window_height = 600,
    });

    var v_shd = try gfx.Shader.init(c.GL_VERTEX_SHADER,
        \\#version 330 core
        \\
        \\layout (location = 0) in vec2 _ext_vertex;
        \\layout (location = 1) in vec2 _ext_uv;
        \\
        \\layout (location = 2) in vec4  _ext_sb_uv;
        \\layout (location = 3) in vec2  _ext_sb_position;
        \\layout (location = 4) in float _ext_sb_rotation;
        \\layout (location = 5) in vec2  _ext_sb_scale;
        \\layout (location = 6) in vec4  _ext_sb_color;
        \\
        \\// basic
        \\uniform mat3 _screen;
        \\uniform mat3 _view;
        \\uniform mat3 _model;
        \\uniform float _time;
        \\uniform int _flip_uvs;
        \\
        \\out vec2 _uv_coord;
        \\out float _tm;
        \\out vec3 _normal;
        \\
        \\// spritebatch
        \\mat3 _sb_model;
        \\out vec4 _sb_color;
        \\out vec2 _sb_uv;
        \\
        \\mat3 mat3_from_transform2d(float x, float y, float sx, float sy, float r) {
        \\    mat3 ret = mat3(1.0);
        \\    float rc = cos(r);
        \\    float rs = sin(r);
        \\    ret[0][0] =  rc * sx;
        \\    ret[0][1] =  rs * sx;
        \\    ret[1][0] = -rs * sy;
        \\    ret[1][1] =  rc * sy;
        \\    ret[2][0] = x;
        \\    ret[2][1] = y;
        \\    return ret;
        \\}
        \\
        \\void ready_spritebatch() {
        \\    // scale main uv coords by sb_uv
        \\    //   automatically handles flip uvs
        \\    //   as long as this is called after flipping the uvs in main (it is)
        \\    float uv_w = _ext_sb_uv.z - _ext_sb_uv.x;
        \\    float uv_h = _ext_sb_uv.w - _ext_sb_uv.y;
        \\    _sb_uv.x = _uv_coord.x * uv_w + _ext_sb_uv.x;
        \\    _sb_uv.y = _uv_coord.y * uv_h + _ext_sb_uv.y;
        \\
        \\    _sb_color = _ext_sb_color;
        \\    _sb_model = mat3_from_transform2d(_ext_sb_position.x,
        \\                                      _ext_sb_position.y,
        \\                                      _ext_sb_scale.x,
        \\                                      _ext_sb_scale.y,
        \\                                      _ext_sb_rotation);
        \\}
        \\
        \\vec3 effect() {
        \\    // return vec3(_ext_vertex, 1.0);
        \\    ready_spritebatch();
        \\    return _screen * _view * _model * _sb_model * vec3(_ext_vertex, 1.0);
        \\    return _screen * _view * _model * vec3(_ext_vertex, 1.0);
        \\}
        \\
        \\void main() {
        \\    _uv_coord = _flip_uvs != 0 ? vec2(_ext_uv.x, 1 - _ext_uv.y) : _ext_uv;
        \\    _tm = _time;
        \\    gl_Position = vec4(effect(), 1.0);
        \\}
    );
    defer v_shd.deinit();

    var f_shd = try gfx.Shader.init(c.GL_FRAGMENT_SHADER,
        \\#version 330 core
        \\
        \\// basic
        \\uniform sampler2D _tx_diffuse;
        \\uniform sampler2D _tx_normal;
        \\uniform vec4 _base_color;
        \\
        \\in vec2 _uv_coord;
        \\in float _tm;
        \\
        \\// spritebatch
        \\in vec4 _sb_color;
        \\in vec2 _sb_uv;
        \\
        \\out vec4 _out_color;
        \\
        \\float _time;
        \\
        \\vec4 effect() {
        \\    return _base_color;
        \\    return _base_color * texture2D(_tx_diffuse, _uv_coord);
        \\}
        \\
        \\void main() {
        \\    _time = _tm;
        \\    _out_color = effect();
        \\}
    );
    defer f_shd.deinit();

    var prog = try gfx.Program.init(&[_]gfx.Shader{ v_shd, f_shd });
    defer prog.deinit();

    var img = try gfx.Image.initFromFile(alloc, "content/mahou.jpg");
    defer img.deinit(alloc);

    std.log.warn("{} {}\n", .{ img.width, img.height });

    var tex = gfx.Texture.init(img);
    defer tex.deinit();

    var quad: [4]flat.Vertex2d = undefined;
    flat.Vertex2d.genQuad(&quad, false);
    var mesh = flat.Mesh2d.init(
        &quad,
        &[_]u32{},
        c.GL_STREAM_DRAW,
        c.GL_TRIANGLE_STRIP,
    );
    defer mesh.deinit();

    const loc = prog.getLocation("_base_color");

    const s_loc = prog.getLocation("_screen");
    const v_loc = prog.getLocation("_view");
    const m_loc = prog.getLocation("_model");

    const mat3 = math.Mat3.identity();

    var sprites: [500]flat.Spritebatch.Sprite = undefined;
    var sb = flat.Spritebatch.init(&sprites);

    std.log.warn("init success\n", .{});

    while (true) {
        c.glfwPollEvents();
        c.glClear(c.GL_COLOR_BUFFER_BIT);

        prog.bind();
        loc.setVec4(math.Vec4(f32).init(1., 1., 1., 1.));

        s_loc.setMat3(math.Mat3.orthoScreen(math.Vec2(u32).init(800, 600)));
        v_loc.setMat3(math.Mat3.identity());
        // m_loc.setMat3(math.Mat3.identity());
        m_loc.setMat3(math.Mat3.fromTransform2d(math.Transform2d.init(-10., -10., 0., 1., 1.)));

        {
            var sp = sb.bind(false);
            defer sp.deinit();

            sp.pull().* = flat.Spritebatch.Sprite{
                .transform = math.Transform2d.init(10., 10., 0., 90., 90.),
            };

            sp.draw();
        }

        // mesh.draw();

        c.glfwSwapBuffers(ctx.window);
    }
}
