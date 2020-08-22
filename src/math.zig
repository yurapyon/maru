fn Vec2(comptime T: type) type {
    return packed struct {
        // TODO make sure T is a float or integer type
        const Self = @This();

        x: T,
        y: T,

        fn init(x: T, y: T) Self {
            return .{
                .x = x,
                .y = y,
            };
        }

        fn add(self: Self, other: Self) Self {
            return .{
                .x = self.x + other.x,
                .y = self.y + other.y,
            };
        }

        fn sub(self: Self, other: Self) Self {
            return .{
                .x = self.x - other.x,
                .y = self.y - other.y,
            };
        }
    };
}

fn AABB(comptime T: type) type {
    return packed struct {
        const Self = @This();

        c1: Vec2(T),
        c2: Vec2(T),
    };
}
