const nitori = @import("nitori");
const Timer = nitori.timer.Timer;

const FrameTimer = struct {
    const Self = @This();

    tm: Timer,
    last: u64,
    last_delta: f64,

    pub fn start() Self {
        const tm = Timer.start();
        return .{
            .tm = tm,
            .last = tm.now(),
            .last_delta = 0.,
        };
    }

    pub fn step(self: *Self) f64 {
        const now = self.tm.now();
        self.last_delta = now - self.last;
        self.last = now;
        return self.last_delta;
    }

    // TODO sleep
};
