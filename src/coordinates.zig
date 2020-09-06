const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const math = @import("math.zig");
const Vec2 = math.Vec2;
const Mat3 = math.Mat3;

//;

pub const Error = error{Underflow};

// TODO take a transform2d and turn it into transforms
//        maybe add shear to transform 2d? kinda weird

pub const CoordinateStack = struct {
    const Self = @This();

    pub const Transform = union(enum) {
        Translate: Vec2,
        Rotate: f32,
        Scale: Vec2,
        Shear: Vec2,
    };

    composed: Mat3,
    stack: ArrayList(Transform),

    pub fn init(allocator: *Allocator) Self {
        return Self{
            .composed = Mat3.identity(),
            .stack = ArrayList(Transform).init(allocator),
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
        if (self.stack.items.len < 1) {
            return error.Underflow;
        }
        const temp = switch (self.stack.pop()) {
            .Translate => |v2| Mat3.translation(v2.neg()),
            .Rotate => |f| Mat3.rotation(-f),
            .Scale => |v2| Mat3.scaling(v2.recip()),
            .Shear => |v2| Mat3.shearing(v2.neg()),
        };
        self.composed = self.composed.mult(temp);
    }
};
