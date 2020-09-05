const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const math = @import("math.zig");
const Vec2 = math.Vec2;
const Mat3 = math.Mat3;

//;

pub const CoordinateStack = struct {
    const Self = @This();

    pub const Transform = union(enum) {
        Translate: Vec2(f32),
        Rotate: f32,
        Scale: Vec2(f32),
        Shear: Vec2(f32),
    };

    // TODO make it so stack is resizable?
    //      or have this not own any data

    composed: Mat3,
    stack: ArrayList(Transform),

    pub fn initCapacity(allocator: *Allocator, size: usize) !Self {
        return Self{
            .composed = Mat3.identity(),
            .stack = try ArrayList(Transform).initCapacity(allocator, size),
        };
    }

    pub fn deinit(self: *Self) void {
        self.stack.deinit();
    }

    //;

    pub fn clear(self: *Self) void {
        self.composed = Mat3.identity();
        self.stack.items.len = 0;
    }

    pub fn push(self: *Self, t: Transform) !void {
        const temp = switch (t) {
            .Translate => |v2| Mat3.translation(v2),
            .Rotate => |f| Mat3.rotation(f),
            .Scale => |v2| Mat3.scaling(v2),
            .Shear => |v2| Mat3.shearing(v2),
        };
        self.composed = self.composed.mult(temp);
        try self.stack.append(t);
    }

    pub fn pop(self: *Self) !void {
        const temp = switch (self.stack.pop() orelse return error.Underflow) {
            .Translate => |v2| Mat3.translation(v2.neg()),
            .Rotate => |f| Mat3.rotation(-f),
            .Scale => |v2| Mat3.scaling(v2.recip()),
            .Shear => |v2| Mat3.shearing(v2.neg()),
        };
        self.composed = self.composed.mult(temp);
    }
};
