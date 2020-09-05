const std = @import("std");
const nitori = @import("nitori");

pub const c = @import("c.zig");
pub const content = @import("content.zig");
pub const gfx = @import("gfx.zig");
pub const math = @import("math.zig");
pub const states = @import("states.zig");

pub const flat = @import("defaults/flat.zig");
pub const drawer2d = @import("defaults/drawer2d.zig");

//;

test "" {
    _ = c;
    _ = content;
    _ = gfx;
    _ = math;
    _ = states;

    _ = flat;
    _ = drawer2d;
}

test "gfx main" {
    const alloc = std.testing.allocator;

    var ctx = try gfx.Context.init(.{
        .window_width = 800,
        .window_height = 600,
    });
    defer ctx.deinit();

    ctx.updateGLFW_WindowUserPtr();

    var evs = ctx.installEventHandler(alloc);

    var prog = try flat.Program2d.initDefaultSpritebatch(alloc);
    defer prog.deinit();

    var img = try gfx.Image.initFromMemory(alloc, content.images.mahou);
    defer img.deinit();

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

    prog.locations.tx_diffuse.setTextureData(.{
        .select = c.GL_TEXTURE0,
        .bind_to = c.GL_TEXTURE_2D,
        .texture = &tex,
    });

    const mat3 = math.Mat3.identity();

    // var sprites: [500]flat.Spritebatch.Sprite = undefined;
    // var sb = flat.Spritebatch.init(&sprites);

    //;

    var defaults = try drawer2d.DrawDefaults.init(alloc);
    defer defaults.deinit();

    var drawer = try drawer2d.Drawer2d.init(alloc, .{
        .coord_stack_size = 20,
        .spritebatch_size = 500,
        .circle_resolution = 50,
    });
    defer drawer.deinit();

    //;

    while (c.glfwWindowShouldClose(ctx.window) == c.GLFW_FALSE) {
        // c.glfwPollEvents();
        evs.poll();

        for (evs.key_events.items) |ev| {
            if (ev.key == .Space) {
                for (evs.gamepads) |gpd| {
                    if (gpd.is_connected) {
                        std.log.warn("{}\n", .{gpd});
                    }
                }
            }
        }

        for (evs.joystick_events.items) |ev| {
            std.log.warn("{}\n", .{ev});
        }

        c.glClear(c.GL_COLOR_BUFFER_BIT);

        {
            var sprites = drawer.bindSpritebatch(false, .{
                .program = &defaults.spritebatch_program,
                .diffuse = &defaults.white_texture,
                .canvas_width = 800,
                .canvas_height = 600,
            });
            defer sprites.deinit();

            sprites.rectangle(10., 10., 50., 50.);
        }

        //         prog.program.bind();
        //         prog.locations.base_color.setVec4(math.Vec4(f32).init(1., 1., 1., 1.));
        //
        //         prog.locations.screen.setMat3(math.Mat3.orthoScreen(math.Vec2(u32).init(800, 600)));
        //         prog.locations.view.setMat3(math.Mat3.identity());
        //         prog.locations.model.setMat3(math.Mat3.fromTransform2d(math.Transform2d.init(0., 0., 0., 1., 1.)));
        //
        //         {
        //             var sp = sb.bind(false);
        //             defer sp.deinit();
        //
        //             sp.pull().* = flat.Spritebatch.Sprite{
        //                 .transform = math.Transform2d.init(10., 10., 0., 90., 90.),
        //             };
        //
        //             sp.draw();
        //         }
        //
        //         // mesh.draw();

        c.glfwSwapBuffers(ctx.window);
    }
}
