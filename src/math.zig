const std = @import("std");

//;

fn assertIsNumberType(comptime T: type) void {
    const type_info = @typeInfo(T);
    std.debug.assert(type_info == .Float or type_info == .Int);
}

pub fn Vec2(comptime T: type) type {
    return extern struct {
        comptime {
            assertIsNumberType(T);
        }

        const Self = @This();

        x: T,
        y: T,

        pub fn init(x: T, y: T) Self {
            return .{
                .x = x,
                .y = y,
            };
        }

        pub fn zero() Self {
            if (@typeInfo(T) == .Float) {
                return .{
                    .x = 0.,
                    .y = 0.,
                };
            } else if (@typeInfo(T) == .Int) {
                return .{
                    .x = 0,
                    .y = 0,
                };
            }
        }

        //;

        pub fn isEqualTo(self: Self, other: Self) bool {
            return self.x == other.x and
                self.y == other.y;
        }

        //;

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

        //;

        pub fn multMat3(self: Vec2(f32), matr: Mat3) Vec2(f32) {
            return .{
                .x = self.x * matr.data[0][0] + self.y * matr.data[1][0] + matr.data[2][0],
                .y = self.x * matr.data[0][1] + self.y * matr.data[1][1] + matr.data[2][1],
            };
        }
    };
}

test "Vec2" {
    const f_zero = Vec2(f32).zero();
    const d_zero = Vec2(f64).zero();
    const i_zero = Vec2(u8).zero();
    const u_zero = Vec2(i8).zero();
}

pub fn Vec3(comptime T: type) type {
    return extern struct {
        comptime {
            assertIsNumberType(T);
        }

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

        //;

        pub fn isEqualTo(self: Self, other: Self) bool {
            return self.x == other.x and
                self.y == other.y and
                self.z == other.z;
        }

        //;

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

        //;

        pub fn multMat3(self: Vec3(f32), matr: Mat3) Vec3(f32) {
            return .{
                .x = self.x * matr.data[0][0] + self.y * matr.data[1][0] + self.z * matr.data[2][0],
                .y = self.x * matr.data[0][1] + self.y * matr.data[1][1] + self.z * matr.data[2][1],
                .z = self.x * matr.data[0][2] + self.y * matr.data[1][2] + self.z * matr.data[2][2],
            };
        }
    };
}

pub fn Vec4(comptime T: type) type {
    return extern struct {
        comptime {
            assertIsNumberType(T);
        }

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

        //;

        pub fn isEqualTo(self: Self, other: Self) bool {
            return self.x == other.x and
                self.y == other.y and
                self.z == other.z and
                self.w == other.w;
        }

        //;

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

//;

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

    pub fn translation(vec: Vec2(f32)) Self {
        var ret = Self.identity();
        ret.data[2][0] = vec.x;
        ret.data[2][1] = vec.y;
        return ret;
    }

    pub fn rotation(rads: f32) Self {
        var ret = Self.identity();
        const rc = std.math.cos(rads);
        const rs = std.math.sin(rads);
        ret.data[0][0] = rc;
        ret.data[0][1] = rs;
        ret.data[1][0] = -rs;
        ret.data[1][1] = rc;
        return ret;
    }

    pub fn scaling(vec: Vec2(f32)) Self {
        var ret = Self.identity();
        ret.data[0][0] = vec.x;
        ret.data[1][1] = vec.y;
        return ret;
    }

    pub fn shearing(vec: Vec2(f32)) Self {
        var ret = Self.identity();
        ret.data[1][0] = vec.x;
        ret.data[0][1] = vec.y;
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

    //;

    pub fn isEqualTo(self: Self, other: Self) bool {
        return self.data[0][0] == other.data[0][0] and
            self.data[1][0] == other.data[1][0] and
            self.data[2][0] == other.data[2][0] and
            self.data[0][1] == other.data[0][1] and
            self.data[1][1] == other.data[1][1] and
            self.data[2][1] == other.data[2][1] and
            self.data[0][2] == other.data[0][2] and
            self.data[1][2] == other.data[1][2] and
            self.data[2][2] == other.data[2][2];
    }

    //;

    // TODO inverse / transpose
    // test m * m' == iden

    pub fn mult(self: Self, other: Self) Self {
        const s = &self.data;
        const o = &other.data;
        return .{
            .data = .{
                .{
                    s[0][0] * o[0][0] + s[0][1] * o[1][0] + s[0][2] * o[2][0],
                    s[0][0] * o[0][1] + s[0][1] * o[1][1] + s[0][2] * o[2][1],
                    s[0][0] * o[0][2] + s[0][1] * o[1][2] + s[0][2] * o[2][2],
                },
                .{
                    s[1][0] * o[0][0] + s[1][1] * o[1][0] + s[1][2] * o[2][0],
                    s[1][0] * o[0][1] + s[1][1] * o[1][1] + s[1][2] * o[2][1],
                    s[1][0] * o[0][2] + s[1][1] * o[1][2] + s[1][2] * o[2][2],
                },
                .{
                    s[2][0] * o[0][0] + s[2][1] * o[1][0] + s[2][2] * o[2][0],
                    s[2][0] * o[0][1] + s[2][1] * o[1][1] + s[2][2] * o[2][1],
                    s[2][0] * o[0][2] + s[2][1] * o[1][2] + s[2][2] * o[2][2],
                },
            },
        };
    }
};

const testing = std.testing;
const expect = testing.expect;

// TODO more tests
test "Mat3" {
    const iden = Mat3.identity();
    const trans = Mat3.translation(Vec2(f32).init(10., 15.));
    expect(trans.isEqualTo(iden.mult(trans)));
    expect(trans.isEqualTo(trans.mult(iden)));

    const v2 = Vec2(f32).init(0., 0.);
    const mul = v2.multMat3(trans);
    expect(mul.isEqualTo(Vec2(f32).init(10., 15.)));
}

//;

pub fn AABB(comptime T: type) type {
    return extern struct {
        comptime {
            assertIsNumberType(T);
        }

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

pub const TextureRegion = AABB(i32);
pub const UV_Region = AABB(f32);

//;

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

//;

pub const Color = extern struct {
    const Self = @This();

    r: f32,
    g: f32,
    b: f32,
    a: f32,

    pub fn initRgba(r: f32, g: f32, b: f32, a: f32) Self {
        return .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }

    pub fn white() Self {
        return Self.initRgba(1., 1., 1., 1.);
    }
};
