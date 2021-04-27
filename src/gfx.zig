const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const c = @import("c.zig");
const events = @import("events.zig");
const EventHandler = events.EventHandler;
const math = @import("math.zig");

//;

// TODO
//   image/texture width and height could be i32, to make it easier to work with texture regions
//     currently only using them to denote "these numbers are positive"

//;

pub var joystick_ctx_reference: ?*Context = null;

pub const Context = struct {
    const Self = @This();

    pub const Error = error{
        GlfwInit,
        WindowInit,
    };

    pub const Settings = struct {
        ogl_version_major: u32 = 3,
        ogl_version_minor: u32 = 3,
        window_width: u32 = 800,
        window_height: u32 = 600,
        window_name: [:0]const u8 = "float",
        is_resizable: bool = true,
        windowSizeCallback: ?fn (*Context) void = null,
    };

    settings: Settings,
    window: *c.GLFWwindow,
    event_handler: ?EventHandler,

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

    pub fn init(self: *Self, settings: Settings) !void {
        if (c.glfwInit() != c.GLFW_TRUE) {
            return error.GlfwInit;
        }
        errdefer c.glfwTerminate();

        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, @intCast(c_int, settings.ogl_version_major));
        c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, @intCast(c_int, settings.ogl_version_minor));
        c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);
        c.glfwWindowHint(c.GLFW_RESIZABLE, if (settings.is_resizable) c.GL_TRUE else c.GL_FALSE);
        c.glfwSwapInterval(1);

        // note: window creation fails if we can't get the desired opengl version

        const window = c.glfwCreateWindow(
            @intCast(c_int, settings.window_width),
            @intCast(c_int, settings.window_height),
            settings.window_name,
            null,
            null,
        ) orelse return error.WindowInit;
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

        self.settings = settings_mut;
        self.window = window;
        self.event_handler = null;

        c.glfwSetWindowUserPointer(window, self);
        joystick_ctx_reference = self;
    }

    pub fn deinit(self: *Self) void {
        if (self.event_handler) |*evs| {
            evs.deinit();
        }
        c.glfwDestroyWindow(self.window);
        c.glfwTerminate();
    }

    //;

    pub fn getFromGLFW_WindowPtr(win: ?*c.GLFWwindow) *Context {
        return @ptrCast(*Context, @alignCast(@alignOf(*Context), c.glfwGetWindowUserPointer(win).?));
    }

    pub fn getFromGLFW_JoystickId(id: c_int) *Context {
        return @ptrCast(*Context, @alignCast(@alignOf(*Context), c.glfwGetJoystickUserPointer(id).?));
    }

    pub fn installEventHandler(self: *Self, allocator: *Allocator) void {
        if (self.event_handler == null) {
            self.event_handler = EventHandler.init(allocator, self.window);
        }
    }
};

//;

pub const Shader = struct {
    const Self = @This();

    pub const Error = error{Compile};

    shader: c.GLuint,

    // TODO to handle errors here probably just use a Result
    // TODO by taking a slice of strings rather than a single string,
    //   flat namespace wont need an allocator for default shader
    //   problem is you gotta turn that slice of slices into a slice of ptrs
    //   or take a slice of ptrs which isnt as nice.
    //   sentineled ptrs?
    pub fn init(ty: c.GLenum, source: [:0]const u8) !Self {
        const shader = c.glCreateShader(ty);
        errdefer c.glDeleteShader(shader);

        c.glShaderSource(shader, 1, &source.ptr, null);
        c.glCompileShader(shader);

        var success: c_int = undefined;
        c.glGetShaderiv(shader, c.GL_COMPILE_STATUS, &success);

        if (success != c.GL_TRUE) {
            // TODO
            var len: c_int = 0;
            c.glGetShaderiv(
                shader,
                c.GL_INFO_LOG_LENGTH,
                &len,
            );
            var buf = try std.testing.allocator.alloc(u8, @intCast(usize, len) + 1);
            defer std.testing.allocator.free(buf);

            c.glGetShaderInfoLog(shader, len, null, buf.ptr);

            std.log.info("{}\n", .{buf});

            return error.Compile;
        }

        return Self{
            .shader = shader,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteShader(self.shader);
    }

    //;
};

pub const Program = struct {
    const Self = @This();

    pub const Error = error{Link};

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
            return error.Link;
        }

        return Self{
            .program = program,
        };
    }

    pub fn deinit(self: *Self) void {
        c.glDeleteProgram(self.program);
    }

    pub fn bind(self: Self) void {
        c.glUseProgram(self.program);
    }

    pub fn unbind(self: Self) void {
        c.glUseProgram(0);
    }

    pub fn getLocation(self: Self, name: [:0]const u8) Location {
        return Location{
            .location = c.glGetUniformLocation(self.program, name),
        };
    }
};

pub const Image = struct {
    const Self = @This();

    const Error = error{Load} || Allocator.Error;

    pub const Color = extern struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    };

    allocator: *Allocator,
    data: []Color,
    width: u32,
    height: u32,

    pub fn init(
        allocator: *Allocator,
        width: u32,
        height: u32,
    ) Allocator.Error!Self {
        const data_len = width * height;
        const data = try allocator.alloc(Color, data_len);
        return Self{
            .allocator = allocator,
            .data = data,
            .width = width,
            .height = height,
        };
    }

    pub fn initFromMemory(allocator: *Allocator, buffer: []const u8) Error!Self {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const raw_data = c.stbi_load_from_memory(
            buffer.ptr,
            @intCast(c_int, buffer.len),
            &w,
            &h,
            null,
            4,
        ) orelse return error.Load;
        defer c.stbi_image_free(raw_data);
        const data_len = @intCast(usize, w * h);

        var data = try allocator.alloc(Color, data_len);
        // TODO alignment
        std.mem.copy(Color, data, @ptrCast([*]Color, raw_data)[0..data_len]);

        return Self{
            .allocator = allocator,
            .data = data,
            .width = @intCast(u32, w),
            .height = @intCast(u32, h),
        };
    }

    pub fn initFromFile(allocator: *Allocator, path: [:0]const u8) Error!Self {
        var w: c_int = undefined;
        var h: c_int = undefined;
        const raw_data = c.stbi_load(path, &w, &h, null, 4) orelse return error.Load;
        defer c.stbi_image_free(raw_data);
        const data_len = @intCast(usize, w * h);

        var data = try allocator.alloc(Color, data_len);
        // TODO alignment
        std.mem.copy(Color, data, @ptrCast([*]Color, raw_data)[0..data_len]);

        return Self{
            .allocator = allocator,
            .data = data,
            .width = @intCast(u32, w),
            .height = @intCast(u32, h),
        };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }
};

pub const Texture = struct {
    const Self = @This();

    texture: c.GLuint,
    width: u32,
    height: u32,

    pub fn init(width: u32, height: u32) Self {
        var tex: c.GLuint = undefined;
        c.glGenTextures(1, &tex);
        c.glBindTexture(c.GL_TEXTURE_2D, tex);

        c.glTexImage2D(
            c.GL_TEXTURE_2D,
            0,
            c.GL_RGBA,
            @intCast(c.GLint, width),
            @intCast(c.GLint, height),
            0,
            c.GL_RGBA,
            c.GL_UNSIGNED_BYTE,
            null,
        );

        c.glBindTexture(c.GL_TEXTURE_2D, 0);

        return .{
            .texture = tex,
            .width = width,
            .height = height,
        };
    }

    pub fn initImage(image: Image) Self {
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
            c.GL_UNSIGNED_BYTE,
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

    //;

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

    pub fn setBorderColor(
        self: *Self,
        r: c.GLfloat,
        g: c.GLfloat,
        b: c.GLfloat,
        a: c.GLfloat,
    ) void {
        const tmp = [_]c.GLfloat{ r, g, b, a };
        c.glBindTexture(c.GL_TEXTURE_2D, self.texture);
        c.glTexParameterfv(c.GL_TEXTURE_2D, c.GL_TEXTURE_BORDER_COLOR, &tmp);
        c.glBindTexture(c.GL_TEXTURE_2D, 0);
    }
};

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

        //;

        pub fn bufferNull(self: Self, len: usize) void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.buffer);
            c.glBufferData(
                c.GL_ARRAY_BUFFER,
                @intCast(c_long, len * @sizeOf(T)),
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

        pub fn subData(self: Self, offset: usize, slice: []const T) void {
            c.glBindBuffer(c.GL_ARRAY_BUFFER, self.buffer);
            c.glBufferSubData(
                c.GL_ARRAY_BUFFER,
                @intCast(c_long, offset),
                @intCast(c_long, slice.len * @sizeOf(T)),
                slice.ptr,
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

    //;

    pub fn enableAttribute(self: Self, num: c.GLuint, attrib: VertexAttribute) void {
        c.glBindVertexArray(self.vertex_array);
        c.glEnableVertexAttribArray(num);
        c.glVertexAttribPointer(
            num,
            @intCast(c_int, attrib.size),
            attrib.ty,
            if (attrib.is_normalized) c.GL_TRUE else c.GL_FALSE,
            @intCast(c_int, attrib.stride),
            @intToPtr(*allowzero const c_void, attrib.offset),
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

// TODO test works
pub const Canvas = struct {
    const Self = @This();

    texture: Texture,
    rbo: c.GLuint,
    fbo: c.GLuint,

    pub fn init(width: u32, height: u32) Self {
        const texture = Texture.init(width, height);

        var rbo = undefined;
        c.glGenRenderbuffers(1, &rbo);
        c.glBindRenderbuffer(c.GL_RENDERBUFFER, rbo);

        c.glRenderbufferStorage(
            c.GL_RENDERBUFFER,
            c.GL_DEPTH24_STENCIL8,
            @intCast(c.GLsizei, width),
            @intCast(c.GLsizei, height),
        );
        c.glBindRenderbuffer(c.GL_RENDERBUFFER, 0);

        var fbo = undefined;
        c.glGenFramebuffers(1, &fbo);
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, fbo);
        c.glFramebufferTexture2D(
            c.GL_FRAMEBUFFER,
            c.GL_COLOR_ATTACHMENT0,
            c.GL_TEXTURE_2D,
            texture.texture,
            0,
        );
        c.glFramebufferRenderbuffer(
            c.GL_FRAMEBUFFER,
            c.GL_DEPTH_STENCIL_ATTACHMENT,
            c.GL_RENDERBUFFER,
            rbo,
        );
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);

        return .{
            .texture = texture,
            .rbo = rbo,
            .fbo = fbo,
        };
    }

    pub fn deinit(self: *Self) void {
        c.DeleteFramebuffers(1, &self.fbo);
        c.DeleteRenderbuffers(1, &self.rbo);
        self.texture.deinit();
    }

    //;

    pub fn bind(self: Self) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, self.fbo);
    }

    pub fn unbind(self: Self) void {
        c.glBindFramebuffer(c.GL_FRAMEBUFFER, 0);
    }

    pub fn setGL_Viewport(self: Self) void {
        c.glViewport(
            0,
            0,
            @intCast(c.GLsizei, self.texture.width),
            @intCast(c.GLsizei, self.texture.height),
        );
    }
};

// TODO
//   make this so this owns its own data as an arraylist ?
//   or set it up like how the buff is, where its just some
//     glbuffers in gpumemory the user can do things with
//   initNull, initFromSlice,
//   subData/bufferData can be called on the buffers here directly
pub fn Mesh(comptime T: type) type {
    return struct {
        const Self = @This();

        //TODO
        // need these in here for length, which is used whenrenering
        //is there a way aroundthis
        vertices: []const T,
        indices: []const u32,
        vao: VertexArray,
        vbo: Buffer(T),
        ebo: Buffer(u32),
        buffer_type: c.GLenum,
        draw_type: c.GLenum,

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
                .vertices = vertices,
                .indices = indices,
                .vao = vao,
                .vbo = vbo,
                .ebo = ebo,
                .buffer_type = buffer_type,
                .draw_type = draw_type,
            };
        }

        pub fn deinit(self: *Self) void {
            self.ebo.deinit();
            self.vbo.deinit();
            self.vao.deinit();
        }

        //;

        pub fn draw(self: Self) void {
            self.vao.bind();
            if (self.indices.len == 0) {
                c.glDrawArrays(
                    self.draw_type,
                    0.,
                    @intCast(c_int, self.vertices.len),
                );
            } else {
                c.glDrawElements(
                    self.draw_type,
                    @intCast(c_int, self.indices.len),
                    c.GL_UNSIGNED_INT,
                    null,
                );
            }
            self.vao.unbind();
        }

        pub fn drawInstanced(self: Self, n: usize) void {
            self.vao.bind();
            if (self.indices.len == 0) {
                c.glDrawArraysInstanced(
                    self.draw_type,
                    0.,
                    @intCast(c_int, self.vertices.len),
                    @intCast(c_int, n),
                );
            } else {
                c.glDrawElementsInstanced(
                    self.draw_type,
                    @intCast(c_int, self.indices.len),
                    c.GL_UNSIGNED_INT,
                    null,
                    @intCast(c_int, n),
                );
            }
            self.vao.unbind();
        }
    };
}

pub const Location = struct {
    const Self = @This();

    const TextureData = struct {
        select: c.GLenum,
        bind_to: c.GLenum,
        texture: *const Texture,
    };

    location: c.GLint,

    pub fn setFloat(self: Self, val: f32) void {
        c.glUniform1f(self.location, val);
    }

    pub fn setInt(self: Self, val: i32) void {
        c.glUniform1i(self.location, val);
    }

    pub fn setUInt(self: Self, val: u32) void {
        c.glUniform1ui(self.location, val);
    }

    pub fn setBool(self: Self, val: bool) void {
        c.glUniform1i(self.location, if (val) 1 else 0);
    }

    pub fn setVec4(self: Self, val: math.Vec4) void {
        c.glUniform4fv(self.location, 1, @ptrCast([*]const f32, &val));
    }

    pub fn setColor(self: Self, val: math.Color) void {
        c.glUniform4fv(self.location, 1, @ptrCast([*]const f32, &val));
    }

    pub fn setMat3(self: Self, val: math.Mat3) void {
        c.glUniformMatrix3fv(
            self.location,
            1,
            c.GL_FALSE,
            @ptrCast([*]const f32, &val.data),
        );
    }

    pub fn setTextureData(self: Self, data: TextureData) void {
        self.setInt(@intCast(c_int, data.select - c.GL_TEXTURE0));
        c.glActiveTexture(data.select);
        c.glBindTexture(data.bind_to, data.texture.texture);
    }
};

pub fn Instancer(comptime T: type) type {
    return struct {
        const Self = @This();

        ibo: Buffer(T),
        data: []T,

        pub fn init(data: []T) Self {
            const ibo = Buffer(T).initNull(data.len, c.GL_STREAM_DRAW);
            return .{
                .ibo = ibo,
                .data = data,
            };
        }

        pub fn deinit(self: *Self) void {
            self.ibo.deinit();
        }

        //;

        pub fn makeVertexArrayCompatible(self: Self, vao: VertexArray) void {
            vao.bind();
            self.ibo.bindTo(c.GL_ARRAY_BUFFER);
            T.setAttributes(vao);
            vao.unbind();
        }

        pub fn bind(self: *Self, comptime M: type, mesh: *const Mesh(M)) BoundInstancer(T, M) {
            return BoundInstancer(T, M){
                .base = self,
                .mesh = mesh,
                .idx = 0,
            };
        }
    };
}

pub fn BoundInstancer(comptime T: type, comptime M: type) type {
    return struct {
        const Self = @This();

        base: *Instancer(T),
        mesh: *const Mesh(M),
        idx: usize,

        pub fn unbind(self: *Self) void {
            if (self.idx != 0) {
                self.draw();
            }
        }

        pub fn draw(self: *Self) void {
            if (self.idx > 0) {
                self.base.ibo.subData(0, self.base.data[0..self.idx]);
                self.mesh.drawInstanced(self.idx);
                self.idx = 0;
            }
        }

        pub fn push(self: *Self, obj: T) void {
            if (self.idx == self.base.data.len) {
                self.draw();
            }
            self.base.data[self.idx] = obj;
            self.idx += 1;
        }

        pub fn pull(self: *Self) *T {
            if (self.idx == self.base.data.len) {
                self.draw();
            }
            const ret = &self.base.data[self.idx];
            self.idx += 1;
            return ret;
        }
    };
}
