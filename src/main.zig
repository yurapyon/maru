const std = @import("std");
const nitori = @import("nitori");

pub const c = @import("c.zig");
pub const content = @import("content.zig");
pub const gfx = @import("gfx.zig");
pub const math = @import("math.zig");
pub const states = @import("states.zig");
pub const events = @import("events.zig");
pub const coords = @import("coordinates.zig");

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

    var img = try gfx.Image.initFromMemory(alloc, content.images.mahou);
    defer img.deinit();

    var tex = gfx.Texture.init(img);
    defer tex.deinit();

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
                .diffuse = &tex,
                .canvas_width = 800,
                .canvas_height = 600,
            });
            defer sprites.deinit();

            sprites.rectangle(0., 0., 400., 300.);
        }

        c.glfwSwapBuffers(ctx.window);
    }
}
