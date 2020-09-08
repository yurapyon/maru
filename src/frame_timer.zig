const nitori = @import("nitori");
const Timer = nitori.timer.Timer;

//;

pub const FrameTimer = struct {
    const Self = @This();

    tm: Timer,
    last: u64,
    last_delta: f64,

    pub fn start() Self {
        var tm = Timer.start();
        return .{
            .tm = tm,
            .last = tm.now(),
            .last_delta = 0.,
        };
    }

    pub fn step(self: *Self) f64 {
        const tm_now = self.tm.now();
        self.last_delta = @intToFloat(f64, tm_now - self.last) / 1000000000.;
        self.last = tm_now;
        return self.last_delta;
    }

    pub fn now(self: Self) u64 {
        return self.tm.now();
    }
};
