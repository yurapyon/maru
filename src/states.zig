const std = @import("std");

const nitori = @import("nitori");
const vtable = nitori.vtable;

const assert = std.debug.assert;

const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// global resources needs a way to allocate new state data

pub fn StateMachine(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const State = struct {
            const VTable = struct {
                pub const Impl = @Type(.Opaque);

                start: ?fn (*Impl, T) void,
                stop: ?fn (*Impl, T) void,
                pause: ?fn (*Impl, T) void,
                unpause: ?fn (*Impl, T) void,
                frame: ?fn (*Impl, T) ?Transition,
                fixed_frame: ?fn (*Impl, T) void,
                frame_hidden: ?fn (*Impl, T) void,
                fixed_frame_hidden: ?fn (*Impl, T) void,

                pub fn start(_s: *Impl, _t: T) void {}
                pub fn stop(_s: *Impl, _t: T) void {}
                pub fn pause(_s: *Impl, _t: T) void {}
                pub fn unpause(_s: *Impl, _t: T) void {}
                pub fn frame(_s: *Impl, _t: T) ?Transition {
                    return null;
                }
                pub fn fixed_frame(_s: *Impl, _t: T) void {}
                pub fn frame_hidden(_s: *Impl, _t: T) void {}
                pub fn fixed_frame_hidden(_s: *Impl, _t: T) void {}
            };

            vtable: *const VTable,
            impl: *VTable.Impl,

            pub fn init(state: anytype) State {
                return .{
                    .vtable = comptime vtable.populate(VTable, @TypeOf(state).Child),
                    .impl = @ptrCast(*VTable.Impl, state),
                };
            }

            pub fn start(self: *State, immut_data: T) void {
                self.vtable.start.?(self.impl, immut_data);
            }

            pub fn stop(self: *State, immut_data: T) void {
                self.vtable.stop.?(self.impl, immut_data);
            }

            pub fn pause(self: *State, immut_data: T) void {
                self.vtable.pause.?(self.impl, immut_data);
            }

            pub fn unpause(self: *State, immut_data: T) void {
                self.vtable.unpause.?(self.impl, immut_data);
            }

            pub fn frame(self: *State, immut_data: T) ?Transition {
                return self.vtable.frame.?(self.impl, immut_data);
            }

            pub fn fixed_frame(self: *State, immut_data: T) void {
                self.vtable.fixed_frame.?(self.impl, immut_data);
            }

            pub fn frame_hidden(self: *State, immut_data: T) void {
                self.vtable.frame_hidden.?(self.impl, immut_data);
            }

            pub fn fixed_frame_hidden(self: *State, immut_data: T) void {
                self.vtable.fixed_frame_hidden.?(self.impl, immut_data);
            }
        };

        pub const Transition = union(enum) {
            Pop,
            Push: State,
            Swap: State,
        };

        //;

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

        // must be called once
        pub fn start(self: *Self, state: State, immut_data: T) !void {
            try self.states.append(state);
            self.states.items[self.states.items.len - 1].start(immut_data);
        }

        pub fn maybe_do_transition(self: *Self, immut_data: T) !void {
            assert(self.states.items.len > 0);
            if (self.transition) |tr| {
                switch (tr) {
                    .Pop => return self.pop(immut_data),
                    .Push => |st| return self.push(st, immut_data),
                    .Swap => |st| return self.swap(st, immut_data),
                }
            }
        }

        pub fn frame(self: *Self, immut_data: T) void {
            assert(self.states.items.len > 0);
            var i: usize = 0;
            while (i < self.states.items.len - 1) : (i += 1) {
                self.states.items[i].frame_hidden(immut_data);
            }
            self.transition = self.states.items[self.states.items.len - 1].frame(immut_data);
        }

        pub fn fixed_frame(self: *Self, immut_data: T) void {
            assert(self.states.items.len > 0);
            var i: usize = 0;
            while (i < self.states.items.len - 1) : (i += 1) {
                self.states.items[i].fixed_frame_hidden(immut_data);
            }
            self.states.items[self.states.items.len - 1].fixed_frame(immut_data);
        }

        //;

        fn pop(self: *Self, immut_data: T) !void {
            assert(self.states.items.len != 0);
            assert(self.states.items.len != 1);

            var prev = self.states.pop().?;
            prev.stop(immut_data);

            var next = self.states.items[self.states.items.len - 1];
            next.unpause(immut_data);
        }

        fn push(self: *Self, state: State, immut_data: T) !void {
            var prev = self.states.items[self.states.items.len - 1];
            prev.pause(immut_data);

            try self.states.append(state);
            var next = self.states.items[self.states.items.len - 1];
            next.start(immut_data);
        }

        fn swap(self: *Self, state: State, immut_data: T) !void {
            assert(self.states.items.len != 0);

            var prev = self.states.pop().?;
            prev.stop(immut_data);

            try self.states.append(state);
            var next = self.states.items[self.states.items.len - 1];
            next.start(immut_data);
        }
    };
}

// tests ===
