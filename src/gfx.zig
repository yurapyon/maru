const std = @import("std");

const c = @import("c.zig");

const Error = error{
    ContextInitError,
    ShaderCompilationError,
    ProgramLinkError,
    ImageInitError,
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
            return error.ContextInitError;
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
        ) orelse return error.ContextInitError;
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

    pub fn init(shaders: []const Shader) !Self {
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

pub const u8Color = packed struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,
};

pub const Image = struct {
    const Self = @This();

    data: []u8Color,
    width: u32,
    height: u32,

    pub fn initFromFile(path: [:0]const u8) !Self {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const raw_data = c.stbi_load(path, &w, &h, null, 4);
        if (raw_data == null) {
            // TODO
            return error.ImageInitError;
        }

        const data_len = @intCast(usize, w * h);
        const data = @ptrCast([*]u8Color, raw_data)[0..data_len];

        return Self{
            .data = data,
            .width = @intCast(u32, w),
            .height = @intCast(u32, h),
        };
    }

    pub fn deinit(self: *Self) void {
        c.stbi_image_free(self.data.ptr);
    }
};

pub const Texture = struct {
    const Self = @This();

    texture: c.GLuint,
    width: u32,
    height: u32,

    pub fn init(image: Image) Self {
        var tex: c.GLuint = undefined;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            @intCast(c.GLint, image.width),
            @intCast(c.GLint, image.height),
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_INT_8_8_8_8_REV,
            image.data.ptr,
        );

        c.glGenerateMipmap(c.GL_TEXTURE_2D);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        var ret = Self{
            .texture = tex,
            .width = image.width,
            .height = image.height,
        };

        ret.setWrap(c.GL_REPEAT, c.GL_REPEAT);
        ret.setFilter(c.GL_LINEAR, c.GL_LINEAR);

        return ret;
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteTextures(1, &self.texture);
    }

    pub fn setWrap(self: *Self, s: c.GLint, t: c.GLint) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_S, s);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_WRAP_T, t);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }

    pub fn setFilter(self: *Self, min: c.GLint, mag: c.GLint) void {
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MIN_FILTER, min);
        c.glTexParameteri(c.GL_TEXTURE_2D, c.GL_TEXTURE_MAG_FILTER, mag);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }
};

// TODO test this
fn Buffer(comptime T: type) type {
    return struct {
        const Self = @This();
        buffer: c.GLuint,
        usage_type: c.GLenum,

        pub fn init(usage_type: c.GLenum) Self {
            var buffer: c.GLuint = undefined;
            c.glGenBuffers(1, &buffer);

            return Self{
                .buffer = buffer,
                .usage_type = usage_type,
            };
        }

        pub fn initNull(len: usize, usage_type: c.GLenum) Self {
            var ret = Self.init(usage_type);
            ret.bufferNull(len);
            return ret;
        }

        pub fn initFromSlice(slice: []const T, usage_type: c.GLenum) Self {
            var ret = Self.init(usage_type);
            ret.bufferData(slice);
            return ret;
        }

        pub fn deinit(self: *Self) void {
            c.glDeleteBuffers(1, &self.buffer);
        }

        pub fn bufferNull(self: Self, len: usize) void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.buffer);
            c.glBufferData(
                c.GL_ARRAY_BUFFER,
                (len * @sizeOf(T)),
                null,
                self.usage_type,
            );
            c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        }

        pub fn bufferData(self: Self, slice: []const T) void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.buffer);
            c.glBufferData(
                c.GL_ARRAY_BUFFER,
                @intCast(c_long, slice.len * @sizeOf(T)),
                slice.ptr,
                self.usage_type,
            );
            c.glBindBuffer(c.GL_ARRAY_BUFFER, 0);
        }

        pub fn bindTo(self: Self, target: c.GLenum) void {
            c.glBindBuffer(target, self.buffer);
        }

        pub fn unbindFrom(target: c.GLenum) void {
            c.glBindBuffer(target, 0);
        }
    };
}

pub const VertexAttribute = struct {
    size: u32,
    ty: c.GLenum,
    is_normalized: bool,
    stride: u32,
    offset: u32,
    divisor: u32,
};

pub const VertexArray = struct {
    const Self = @This();

    vertex_array: c.GLuint,

    pub fn init() Self {
        var vertex_array: c.GLuint = undefined;
        c.glGenVertexArrays(1, &vertex_array);
        return Self{
            .vertex_array = vertex_array,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteVertexArrays(1, &self.vertex_array);
    }

    pub fn enableAttribute(self: Self, num: c.GLuint, attrib: VertexAttribute) void {
        c.glBindVertexArray(self.vertex_array);
        c.glEnableVertexAttribArray(num);
        c.glVertexAttribPointer(
            num,
            @intCast(c_int, attrib.size),
            attrib.ty,
            if (attrib.is_normalized) c.GL_TRUE else c.GL_FALSE,
            @intCast(c_int, attrib.stride),
            @intToPtr(*const c_void, attrib.offset),
        );
        c.glVertexAttribDivisor(num, @intCast(c_uint, attrib.divisor));
    }

    pub fn disableAttribute(self: Self, num: c.GLuint) void {
        c.glBindVertexArray(self.vertex_array);
        c.glDisableVertexAttribArray(num);
    }

    pub fn bind(self: Self) void {
        c.glBindVertexArray(self.vertex_array);
    }

    pub fn unbind(self: Self) void {
        c.glBindVertexArray(0);
    }
};

pub fn Mesh(comptime T: type) type {
    return struct {
        const Self = @This();

        vao: VertexArray,
        vbo: Buffer(T),
        ebo: Buffer(u32),
        buffer_type: c.GLenum,
        draw_type: c.GLenum,

        // TODO think abt how one might update verts later on

        pub fn init(
            vertices: []const T,
            indices: []const u32,
            buffer_type: c.GLenum,
            draw_type: c.GLenum,
        ) Self {
            var vao = VertexArray.init();
            const vbo = Buffer(T).initFromSlice(vertices, buffer_type);
            const ebo = Buffer(u32).initFromSlice(indices, buffer_type);

            vao.bind();
            vbo.bindTo(c.GL_ARRAY_BUFFER);
            T.setAttributes(&vao);
            ebo.bindTo(c.GL_ELEMENT_ARRAY_BUFFER);
            vao.unbind();

            return Self{
                .vao = vao,
                .vbo = vbo,
                .ebo = ebo,
                .buffer_type = buffer_type,
                .draw_type = draw_type,
            };
        }

        pub fn deinit(self: *Self) void {
            self.vao.deinit();
            self.vbo.deinit();
            self.ebo.deinit();
        }
    };
}
