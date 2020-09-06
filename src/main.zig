const std = @import("std");

pub const c = @import("c.zig");
pub const content = @import("content.zig");
pub const coordinates = @import("coordinates.zig");
pub const events = @import("events.zig");
pub const frame_timer = @import("frame_timer.zig");
pub const gfx = @import("gfx.zig");
pub const math = @import("math.zig");
pub const states = @import("states.zig");
pub const tiled = @import("tiled.zig");

pub const flat = @import("defaults/flat.zig");

//;

test "" {
    _ = c;
    _ = content;
    _ = coordinates;
    _ = events;
    _ = frame_timer;
    _ = gfx;
    _ = math;
    _ = states;
    _ = tiled;

    _ = flat;
}

test "gfx main" {
    const alloc = std.testing.allocator;

    var ctx: gfx.Context = undefined;
    try ctx.init(.{
        .window_width = 800,
        .window_height = 600,
    });
    defer ctx.deinit();

    ctx.installEventHandler(alloc);

    const evs = &ctx.event_handler.?;

    var img = try gfx.Image.initFromMemory(alloc, content.images.mahou);
    defer img.deinit();

    var tex = gfx.Texture.init(img);
    defer tex.deinit();

    //;

    var defaults = try flat.DrawDefaults.init(alloc);
    defer defaults.deinit();

    var drawer = try flat.Drawer2d.init(alloc, .{
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
            defer sprites.unbind();

            sprites.rectangle(10., 10., 410., 310.);
            try sprites.pushCoord(.{ .Shear = math.Vec2(f32).init(1., 0.) });
            try sprites.pushCoord(.{ .Scale = math.Vec2(f32).init(1., 0.5) });
            sprites.rectangle(0., 0., 400., 300.);
            try sprites.popCoord();
            try sprites.popCoord();
        }

        c.glfwSwapBuffers(ctx.window);
    }
}
