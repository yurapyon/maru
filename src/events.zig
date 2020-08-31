const builtin = @import("builtin");
const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const c = @import("c.zig");
const gfx = @import("gfx.zig");

//;

pub const KeyEvent = struct {
    const Self = @This();

    pub const Key = enum(i16) {
        Unknown = -1,
        Space = 32,
        Apostrophe = 39,
        Comma = 44,
        Minus = 45,
        Period = 46,
        Slash = 47,
        KB_0 = 48,
        KB_1 = 49,
        KB_2 = 50,
        KB_3 = 51,
        KB_4 = 52,
        KB_5 = 53,
        KB_6 = 54,
        KB_7 = 55,
        KB_8 = 56,
        KB_9 = 57,
        Semicolon = 59,
        Equal = 61,
        A = 65,
        B = 66,
        C = 67,
        D = 68,
        E = 69,
        F = 70,
        G = 71,
        H = 72,
        I = 73,
        J = 74,
        K = 75,
        L = 76,
        M = 77,
        N = 78,
        O = 79,
        P = 80,
        Q = 81,
        R = 82,
        S = 83,
        T = 84,
        U = 85,
        V = 86,
        W = 87,
        X = 88,
        Y = 89,
        Z = 90,
        LeftBracket = 91,
        Backslash = 92,
        RightBracket = 93,
        GraveAccent = 96,
        World1 = 161,
        World2 = 162,
        Escape = 256,
        Enter = 257,
        Tab = 258,
        Backspace = 259,
        Insert = 260,
        Delete = 261,
        Right = 262,
        Left = 263,
        Down = 264,
        Up = 265,
        PageUp = 266,
        PageDown = 267,
        Home = 268,
        End = 269,
        CapsLock = 280,
        ScrollLock = 281,
        NumLock = 282,
        PrintScreen = 283,
        Pause = 284,
        F1 = 290,
        F2 = 291,
        F3 = 292,
        F4 = 293,
        F5 = 294,
        F6 = 295,
        F7 = 296,
        F8 = 297,
        F9 = 298,
        F10 = 299,
        F11 = 300,
        F12 = 301,
        F13 = 302,
        F14 = 303,
        F15 = 304,
        F16 = 305,
        F17 = 306,
        F18 = 307,
        F19 = 308,
        F20 = 309,
        F21 = 310,
        F22 = 311,
        F23 = 312,
        F24 = 313,
        F25 = 314,
        KP_0 = 320,
        KP_1 = 321,
        KP_2 = 322,
        KP_3 = 323,
        KP_4 = 324,
        KP_5 = 325,
        KP_6 = 326,
        KP_7 = 327,
        KP_8 = 328,
        KP_9 = 329,
        KP_Decimal = 330,
        KP_Divide = 331,
        KP_Multiply = 332,
        KP_Subtract = 333,
        KP_Add = 334,
        KP_Enter = 335,
        KP_Equal = 336,
        LeftShift = 340,
        LeftControl = 341,
        LeftAlt = 342,
        LeftSuper = 343,
        RightShift = 344,
        RightControl = 345,
        RightAlt = 346,
        RightSuper = 347,
        Menu = 348,
    };

    pub const Action = enum {
        Press,
        Repeat,
        Release,
    };

    pub const Mods = packed struct {
        shift: bool,
        control: bool,
        alt: bool,
        super: bool,
        caps_lock: bool,
        num_lock: bool,
    };

    key: Key,
    scancode: ?u32,
    action: Action,
    mods: Mods,

    fn init(key: c_int, scancode: c_int, action: c_int, raw_mods: c_int) Self {
        const mods = .{
            .shift = (raw_mods & c.GLFW_MOD_SHIFT) != 0,
            .control = (raw_mods & c.GLFW_MOD_CONTROL) != 0,
            .alt = (raw_mods & c.GLFW_MOD_ALT) != 0,
            .super = (raw_mods & c.GLFW_MOD_SUPER) != 0,
            .caps_lock = (raw_mods & c.GLFW_MOD_CAPS_LOCK) != 0,
            .num_lock = (raw_mods & c.GLFW_MOD_NUM_LOCK) != 0,
        };

        return .{
            .key = @intToEnum(Key, @intCast(i16, key)),
            .scancode = if (scancode < 0) null else @intCast(u32, scancode),
            .action = switch (action) {
                c.GLFW_PRESS => Action.Press,
                c.GLFW_REPEAT => Action.Repeat,
                c.GLFW_RELEASE => Action.Release,
                else => unreachable,
            },
            .mods = mods,
        };
    }
};

pub const CharEvent = struct {
    const Self = @This();

    buf: [4]u8,
    len: u3,

    fn init(raw_codepoint: c_uint) Self {
        var ret: Self = undefined;
        ret.len = std.unicode.utf8Encode(@intCast(u21, raw_codepoint), &ret.buf) catch 0;
        return ret;
    }
};

// TODO joystick/ gamepad
//  mouse events, cursor motion/ buttons

pub const EventHandler = struct {
    const Self = @This();

    key_events: ArrayList(KeyEvent),
    char_events: ArrayList(CharEvent),

    pub fn init(allocator: *Allocator, window: *c.GLFWwindow) Self {
        _ = c.glfwSetKeyCallback(window, keyCallback);
        _ = c.glfwSetCharCallback(window, charCallback);
        return .{
            .key_events = ArrayList(KeyEvent).init(allocator),
            .char_events = ArrayList(CharEvent).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.char_events.deinit();
        self.key_events.deinit();
    }

    pub fn poll(self: *Self) void {
        self.key_events.items.len = 0;
        self.char_events.items.len = 0;
        c.glfwPollEvents();
    }

    //;

    fn keyCallback(
        win: ?*c.GLFWwindow,
        key: c_int,
        scancode: c_int,
        action: c_int,
        mods: c_int,
    ) callconv(.C) void {
        var ctx = gfx.Context.getFromGLFW_WindowPtr(win);
        var evs = &ctx.event_handler.?;
        // TODO do something on allocator fail
        //    just do nothing?
        evs.key_events.append(KeyEvent.init(key, scancode, action, mods)) catch unreachable;
    }

    fn charCallback(
        win: ?*c.GLFWwindow,
        codepoint: c_uint,
    ) callconv(.C) void {
        var ctx = gfx.Context.getFromGLFW_WindowPtr(win);
        var evs = &ctx.event_handler.?;
        evs.char_events.append(CharEvent.init(codepoint)) catch unreachable;
    }
};
