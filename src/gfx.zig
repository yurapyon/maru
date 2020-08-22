const std = @import("std");

const c = @import("c.zig");

const Error = error{
    InitializationError,
    ShaderCompilationError,
    ProgramLinkError,
};

pub const Context = struct {
    pub const Settings = struct {
        ogl_version_major: u32 = 3,
        ogl_version_minor: u32 = 3,
        window_width: u32 = 800,
        window_height: u32 = 600,
        window_name: [:0]const u8 = "float",
        is_resizable: bool = true,
        windowSizeCallback: ?fn (*Context) void = null,
    };

    const Self = @This();

    settings: Settings,
    window: *c.GLFWwindow,

    fn windowSizeCallback(
        win: ?*c.GLFWwindow,
        width: c_int,
        height: c_int,
    ) callconv(.C) void {
        var ctx = @ptrCast(*Context, @alignCast(@alignOf(*Context), c.glfwGetWindowUserPointer(win).?));
        ctx.settings.window_width = @intCast(u32, width);
        ctx.settings.window_height = @intCast(u32, height);
        if (ctx.settings.windowSizeCallback) |cb| {
            cb(ctx);
        }
    }

    pub fn init(settings: Settings) !Self {
        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.InitializationError;
        }

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, @intCast(c_int, settings.ogl_version_major));
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, @intCast(c_int, settings.ogl_version_minor));
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_RESIZABLE, if (settings.is_resizable) c.GL_TRUE else c.GL_FALSE);
        c.glfwSwapInterval(1);

        const window = c.glfwCreateWindow(
            @intCast(c_int, settings.window_width),
            @intCast(c_int, settings.window_height),
            settings.window_name,
            null,
            null,
        ) orelse return error.InitializationError;
        errdefer c.glfwDestroyWindow(window);

        c.glfwMakeContextCurrent(window);

        var w: c_int = undefined;
        var h: c_int = undefined;
        c.glfwGetFramebufferSize(window, &w, &h);
        c.glViewport(0, 0, w, h);
        _ = c.glfwSetWindowSizeCallback(window, windowSizeCallback);

        c.glEnable(c.GL_BLEND);
        c.glBlendEquation(c.GL_FUNC_ADD);
        c.glBlendFunc(c.GL_SRC_ALPHA, c.GL_ONE_MINUS_SRC_ALPHA);
        c.glClearColor(0, 0, 0, 0);

        var settings_mut = settings;
        settings_mut.window_width = @intCast(u32, w);
        settings_mut.window_height = @intCast(u32, h);

        var ret = Self{
            .settings = settings_mut,
            .window = window,
        };
        c.glfwSetWindowUserPointer(window, &ret);
        return ret;
    }

    fn deinit(self: *Self) void {
        c.glfwDestroyWindow(self.window);
    }
};

pub const Shader = struct {
    const Self = @This();

    shader: c.GLuint,

    pub fn init(ty: c.GLenum, source: [:0]const u8) !Self {
        const shader = c.glCreateShader(ty);
        errdefer c.glDeleteShader(shader);

        c.glShaderSource(shader, 1, &source.ptr, null);
        c.glCompileShader(shader);

        var success: c_int = undefined;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);

        if (success != c.GL_TRUE) {
            // TODO
            return error.ShaderCompilationError;
        }

        return Self{
            .shader = shader,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteShader(self.shader);
    }
};

pub const Program = struct {
    const Self = @This();

    program: c.GLuint,

    pub fn init(shaders: []Shader) !Self {
        const program = c.glCreateProgram();
        errdefer c.glDeleteProgram(program);

        for (shaders) |shd| {
            c.glAttachShader(program, shd.shader);
        }

        c.glLinkProgram(program);

        var success: c_int = undefined;
        c.glGetProgramiv(program, c.GL_LINK_STATUS, &success);

        if (success != c.GL_TRUE) {
            // TODO
            return error.ProgramLinkError;
        }

        return Self{
            .program = program,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteProgram(self.program);
    }
};
