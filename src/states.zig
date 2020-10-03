const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const assert = std.debug.assert;

const nitori = @import("nitori");
const interface = nitori.interface;

//;

// start is used for initializing load routines
//   init data and allocate
//   TODO should statemachine return allocator errors?
// stop is used for deiniting data

// states will need to allocate
//   better to do it in start and stop rather than init and deinit
//     states are usually single purpose and only serve to be put in the state machine
//   allocations for the actual state instances should be handled by some global ctx
//   state machine doesnt care

//;

pub const Transition = union(enum) {
    Pop,
    Push: State,
    Swap: State,
};

pub const State = struct {
    const VTable = struct {
        start: fn (State) void = _start,
        stop: fn (State) void = _stop,
        pause: fn (State) void = _pause,
        unpause: fn (State) void = _unpause,
        frame: fn (State) ?Transition = _frame,
        fixed_frame: fn (State) void = _fixed_frame,
        frame_hidden: fn (State) void = _frame_hidden,
        fixed_frame_hidden: fn (State) void = _fixed_frame_hidden,

        pub fn _start(_s: State) void {}
        pub fn _stop(_s: State) void {}
        pub fn _pause(_s: State) void {}
        pub fn _unpause(_s: State) void {}
        pub fn _frame(_s: State) ?Transition {
            return null;
        }
        pub fn _fixed_frame(_s: State) void {}
        pub fn _frame_hidden(_s: State) void {}
        pub fn _fixed_frame_hidden(_s: State) void {}
    };

    impl: interface.Impl,
    vtable: *const VTable,
};

pub const StateMachine = struct {
    const Self = @This();

    states: ArrayList(State),
    transition: ?Transition,

    pub fn init(allocator: *Allocator) Self {
        const states = ArrayList(State).init(allocator);
        return .{
            .states = states,
            .transition = null,
        };
    }

    pub fn deinit(self: *Self) void {
        self.states.deinit();
    }

    //;

    pub fn start(self: *Self, state: State) Allocator.Error!void {
        try self.states.append(state);
        state.vtable.start(state);
    }

    pub fn stop(self: *Self) void {
        // TODO
        // assert theres only one state?
        // stop all states
    }

    pub fn maybe_do_transition(self: *Self) Allocator.Error!void {
        if (self.transition) |tr| {
            switch (tr) {
                .Pop => self.pop(),
                .Push => |st| try self.push(st),
                .Swap => |st| try self.swap(st),
            }
        }
    }

    pub fn frame(self: *Self) void {
        assert(self.states.items.len > 0);
        for (self.states.items[0..(self.states.items.len - 1)]) |state| {
            state.vtable.frame_hidden(state);
        }
        const last_state = self.states.items[self.states.items.len - 1];
        self.transition = last_state.vtable.frame(last_state);
    }

    pub fn fixed_frame(self: *Self) void {
        assert(self.states.items.len > 0);
        for (self.states.items[0..(self.states.items.len - 1)]) |state| {
            state.vtable.fixed_frame_hidden(state);
        }
        const last_state = self.states.items[self.states.items.len - 1];
        last_state.vtable.fixed_frame(last_state);
    }

    //;

    fn pop(self: *Self) void {
        assert(self.states.items.len != 0);
        assert(self.states.items.len != 1);

        var prev = self.states.pop();
        prev.vtable.stop(prev);

        var next = self.states.items[self.states.items.len - 1];
        next.vtable.unpause(next);
    }

    fn push(self: *Self, state: State) Allocator.Error!void {
        var prev = self.states.items[self.states.items.len - 1];
        prev.vtable.pause(prev);

        try self.states.append(state);
        var next = self.states.items[self.states.items.len - 1];
        next.vtable.start(next);
    }

    fn swap(self: *Self, state: State) Allocator.Error!void {
        assert(self.states.items.len != 0);

        var prev = self.states.pop();
        prev.vtable.stop(prev);

        try self.states.append(state);
        var next = self.states.items[self.states.items.len - 1];
        next.vtable.start(next);
    }
};

// tests ===

const A = struct {
    const Self = @This();

    x: u8,

    fn state(self: *Self) State {
        return .{
            .impl = interface.Impl.init(self),
            .vtable = &comptime State.VTable{
                .start = start,
                .stop = stop,
                .pause = pause,
                .unpause = unpause,
                .frame = frame,
                .fixed_frame = fixed_frame,
                .frame_hidden = frame_hidden,
                .fixed_frame_hidden = fixed_frame_hidden,
            },
        };
    }

    fn start(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("start A {}\n", .{self.x});
    }

    fn stop(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("stop A {}\n", .{self.x});
    }

    fn pause(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("pause A {}\n", .{self.x});
    }

    fn unpause(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("unpause A {}\n", .{self.x});
    }

    fn frame(s: State) ?Transition {
        var self = s.impl.cast(Self);
        std.log.warn("frame A {}\n", .{self.x});
        return null;
    }

    fn fixed_frame(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("fixed_frame A {}\n", .{self.x});
    }

    fn frame_hidden(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("frame_hidden A {}\n", .{self.x});
    }

    fn fixed_frame_hidden(s: State) void {
        var self = s.impl.cast(Self);
        std.log.warn("fixed_frame_hidden A {}\n", .{self.x});
    }
};

// tests ===

// TODO test transitions work when returned from frame funcs

test "StateMachine" {
    var sm = StateMachine.init(std.testing.allocator);
    defer sm.deinit();

    var a1 = A{ .x = 1 };
    var a2 = A{ .x = 2 };
    var a3 = A{ .x = 3 };

    try sm.start(a1.state());
    sm.frame();
    sm.fixed_frame();

    try sm.push(a2.state());
    sm.frame();
    sm.fixed_frame();

    try sm.swap(a3.state());
    sm.frame();
    sm.fixed_frame();

    sm.pop();

    sm.stop();
}
