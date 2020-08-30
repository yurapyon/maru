const std = @import("std");

pub fn Vec2(comptime T: type) type {
    return extern struct {
        const Self = @This();

        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            return .{
                .x = x,
                .y = y,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }
    };
}

pub fn Vec3(comptime T: type) type {
    return extern struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            return .{
                .x = x,
                .y = y,
                .z = z,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
            };
        }
    };
}

pub fn Vec4(comptime T: type) type {
    return extern struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,
        w: T,

        pub fn init(x: T, y: T, z: T, w: T) Self {
            return .{
                .x = x,
                .y = y,
                .z = z,
                .w = w,
            };
        }

        pub fn add(self: Self, other: Self) Self {
            return .{
                .x = self.x + other.x,
                .y = self.y + other.y,
                .z = self.z + other.z,
                .w = self.w + other.w,
            };
        }

        pub fn sub(self: Self, other: Self) Self {
            return .{
                .x = self.x - other.x,
                .y = self.y - other.y,
                .z = self.z - other.z,
                .w = self.w - other.w,
            };
        }
    };
}

// ===

pub const Mat3 = struct {
    const Self = @This();

    // column major
    data: [3][3]f32,

    pub fn zero() Self {
        var ret = Self{ .data = undefined };
        var i: usize = 0;
        var j: usize = 0;
        while (i < 3) : (i += 1) {
            j = 0;
            while (j < 3) : (j += 1) {
                ret.data[i][j] = 0.;
            }
        }
        return ret;
    }

    pub fn identity() Self {
        var ret = Self.zero();
        ret.data[0][0] = 1.;
        ret.data[1][1] = 1.;
        ret.data[2][2] = 1.;
        return ret;
    }

    pub fn orthoScreen(dimensions: Vec2(u32)) Self {
        var ret = Self.identity();
        ret.data[0][0] = 2. / @intToFloat(f32, dimensions.x);
        ret.data[1][1] = -2. / @intToFloat(f32, dimensions.y);
        ret.data[2][0] = -1.;
        ret.data[2][1] = 1.;
        return ret;
    }

    pub fn fromTransform2d(t2d: Transform2d) Self {
        var ret = Self.identity();
        const sx = t2d.scale.x;
        const sy = t2d.scale.y;
        const rc = std.math.cos(t2d.rotation);
        const rs = std.math.sin(t2d.rotation);
        ret.data[0][0] = rc * sx;
        ret.data[0][1] = rs * sx;
        ret.data[1][0] = -rs * sy;
        ret.data[1][1] = rc * sy;
        ret.data[2][0] = t2d.position.x;
        ret.data[2][1] = t2d.position.y;
        return ret;
    }
};

// ===

pub fn AABB(comptime T: type) type {
    return extern struct {
        const Self = @This();

        c1: Vec2(T),
        c2: Vec2(T),

        pub fn init(x1: T, y1: T, x2: T, y2: T) Self {
            return .{
                .c1 = Vec2(T).init(x1, y1),
                .c2 = Vec2(T).init(x2, y2),
            };
        }
    };
}

pub const Transform2d = extern struct {
    const Self = @This();

    position: Vec2(f32),
    rotation: f32,
    scale: Vec2(f32),

    pub fn init(x: f32, y: f32, r: f32, sx: f32, sy: f32) Self {
        return .{
            .position = Vec2(f32).init(x, y),
            .rotation = r,
            .scale = Vec2(f32).init(sx, sy),
        };
    }

    pub fn identity() Self {
        return Self.init(0., 0., 0., 1., 1.);
    }
};

// ==

pub const Color = extern struct {
    const Self = @This();

    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn init_rgba(r: f32, g: f32, b: f32, a: f32) Self {
        return .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }

    pub fn white() Self {
        return Self.init_rgba(1., 1., 1., 1.);
    }
};

// ===

pub const UvRegion = AABB(f32);
pub const TextureRegion = AABB(i32);
