const std = @import("std");
const Allocator = std.mem.Allocator;
const json = std.json;

//;

const c = @import("c.zig");
const math = @import("math.zig");
usingnamespace math;

//;

// glfw parser thing
//   parse the base64 buffers to u8 buffer

// for default 3d utils
//   have 3d mesh
//   materials
//   animations
//     skeletal and morph
//       skeletal: vertex shader
//       morph: also in vertex shader?
//     default animated shader

// TODO uri type?

//;

fn jsonValueDeepClone(allocator: *Allocator, j: json.Value) Allocator.Error!json.Value {
    switch (j) {
        .Null => return json.Value.Null,
        .Bool => |val| return json.Value{ .Bool = val },
        .Integer => |val| return json.Value{ .Integer = val },
        .Float => |val| return json.Value{ .Float = val },
        .String => |val| return json.Value{ .String = try allocator.dupe(u8, val) },
        .Array => |val| {
            var arr = try json.Array.initCapacity(allocator, val.items.len);
            for (val.items) |i| {
                try arr.append(try jsonValueDeepClone(allocator, i));
            }
            return json.Value{ .Array = arr };
        },
        .Object => |val| {
            var ht = json.ObjectMap.init(allocator);
            var iter = val.iterator();
            while (iter.next()) |entry| {
                try ht.put(entry.key, try jsonValueDeepClone(allocator, entry.value));
            }
            return json.Value{ .Object = ht };
        },
    }
}

fn jsonValueFreeClone(allocator: *Allocator, j: *json.Value) void {
    switch (j.*) {
        .String => |val| allocator.free(val),
        .Array => |*val| {
            for (val.items) |*i| {
                jsonValueFreeClone(allocator, i);
            }
            val.deinit();
        },
        .Object => |*val| {
            var iter = val.iterator();
            while (iter.next()) |entry| {
                jsonValueFreeClone(allocator, &entry.value);
            }
            val.deinit();
        },
        else => {},
    }
}

//;

pub const Accessor = struct {
    pub const ComponentType = enum(c.GLenum) {
        Byte = c.GL_BYTE,
        UnsignedByte = c.GL_UNSIGNED_BYTE,
        Short = c.GL_SHORT,
        UnsignedShort = c.GL_UNSIGNED_SHORT,
        UnsignedInt = c.GL_UNSIGNED_INT,
        Float = c.GL_FLOAT,
    };

    pub const DataType = enum {
        Scalar,
        Vec2,
        Vec3,
        Vec4,
        Mat2,
        Mat3,
        Mat4,
    };

    buffer_view: ?usize = null,
    byte_offset: ?usize = 0,
    component_type: ComponentType,
    normalized: ?bool = false,
    count: usize,
    data_type: DataType,
    // TODO min max
    // TODO sparse
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO animation

pub const Asset = struct {
    copyright: ?[]u8 = null,
    generator: ?[]u8 = null,
    version: []const u8,
    min_version: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Buffer = struct {
    uri: ?[]u8 = null,
    byte_length: usize,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const BufferView = struct {
    buffer: usize,
    byte_offset: ?usize = 0,
    byte_length: usize,
    byte_stride: ?usize = null,
    // TODO target type
    target: ?c.GLenum = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Camera = struct {
    pub const CameraType = enum {
        Orthographic,
        Perspective,
    };

    orthographic: ?Orthographic = null,
    perspective: ?Perspective = null,
    camera_type: ?CameraType = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO channel

pub const Extensions = json.Value;
pub const Extras = json.Value;

pub const Image = struct {
    pub const MimeType = enum {
        JPEG,
        PNG,
    };

    uri: ?[]u8 = null,
    buffer_view: ?usize = null,
    mime_type: ?MimeType = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// sparse indices

pub const Material = struct {
    pub const AlphaMode = enum {
        Opaque,
        Mask,
        Blend,
    };

    pbr_metallic_roughness: ?PbrMetallicRoughness = .{},
    normal_texture: ?NormalTextureInfo = null,
    occlusion_texture: ?OcclusionTextureInfo = null,
    emissive_texture: ?TextureInfo = null,
    emissive_factor: ?Color = Color.black(),
    alpha_mode: ?AlphaMode = .Opaque,
    alpha_cutoff: ?f32 = 0.5,
    double_sided: ?bool = false,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Mesh = struct {
    primitives: []Primitive,
    weights: ?[]f32 = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Node = struct {
    camera: ?usize = null,
    children: ?[]usize = null,
    // TODO skin
    matrix: ?Mat4 = Mat4.identity(),
    mesh: ?usize = null,
    transform: ?Transform3d = Transform3d.identity(),
    // TODO weights
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const NormalTextureInfo = struct {
    index: usize,
    tex_coord: ?usize = 0,
    scale: ?f32 = 1,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const OcclusionTextureInfo = struct {
    index: usize,
    tex_coord: ?usize = 0,
    strength: ?f32 = 1,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Orthographic = struct {
    xmag: f32,
    ymag: f32,
    zfar: f32,
    znear: f32,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const PbrMetallicRoughness = struct {
    base_color_factor: ?Color = Color.white(),
    base_color_texture: ?TextureInfo = null,
    metallic_factor: ?f32 = 1,
    roughness_factor: ?f32 = 1,
    metallic_roughness_texture: ?TextureInfo = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Perspective = struct {
    aspect_ratio: ?f32 = null,
    yfov: f32,
    zfar: ?f32 = null,
    znear: f32,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Primitive = struct {
    pub const AttributeType = union(enum) {
        Position,
        Normal,
        Tangent,
        TexCoord0,
        TexCoord1,
        Color0,
        Joints0,
        Weights0,
        Custom: []u8,
    };

    // TODO verify
    pub const Attribute = struct {
        attribute_type: AttributeType,
        accessor: usize,
    };

    pub const TargetType = enum {
        Position,
        Normal,
        Tangent,
    };

    pub const Target = struct {
        target_type: TargetType,
        accessor: usize,
    };

    pub const Mode = enum(c.GLenum) {
        Points = c.GL_POINTS,
        Lines = c.GL_LINES,
        LineLoop = c.GL_LINE_LOOP,
        LineStrip = c.GL_LINE_STRIP,
        Triangles = c.GL_TRIANGLES,
        TriangleStrip = c.GL_TRIANGLE_STRIP,
        TriangleFan = c.GL_TRIANGLE_FAN,
    };

    attributes: []Attribute,
    indices: ?usize = null,
    material: ?usize = null,
    mode: ?Mode = .Triangles,
    targets: ?[]Target = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Sampler = struct {
    pub const Filter = enum(c.GLenum) {
        Nearest = c.GL_NEAREST,
        Linear = c.GL_LINEAR,
        NearestMipmapNearest = c.GL_NEAREST_MIPMAP_NEAREST,
        LinearMipmapNearest = c.GL_LINEAR_MIPMAP_NEAREST,
        NearestMipmapLinear = c.GL_NEAREST_MIPMAP_LINEAR,
        LinearMipmapLinear = c.GL_LINEAR_MIPMAP_LINEAR,
    };

    pub const Wrap = enum(c.GLenum) {
        ClampToEdge = c.GL_CLAMP_TO_EDGE,
        MirroredRepeat = c.GL_MIRRORED_REPEAT,
        Repeat = c.GL_REPEAT,
    };

    max_filter: ?Filter = null,
    min_filter: ?Filter = null,
    wrap_s: ?Wrap = .Repeat,
    wrap_t: ?Wrap = .Repeat,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const Scene = struct {
    nodes: ?[]usize = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// TODO skin
// TODO sparse
// TODO target

pub const Texture = struct {
    source: ?usize = null,
    sampler: ?usize = null,
    name: ?[]u8 = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

pub const TextureInfo = struct {
    index: usize,
    tex_coord: ?usize = 0,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

// sparse values

//;

pub const GlTF = struct {
    extensions_used: ?[][]u8 = null,
    extensions_required: ?[][]u8 = null,
    accessors: ?[]Accessor = null,
    // animations
    asset: Asset,
    buffers: ?[]Buffer = null,
    buffer_views: ?[]BufferView = null,
    cameras: ?[]Camera = null,
    images: ?[]Image = null,
    materials: ?[]Material = null,
    meshes: ?[]Mesh = null,
    nodes: ?[]Node = null,
    samplers: ?[]Sampler = null,
    scene: ?usize = null,
    scenes: ?[]Scene = null,
    // skins
    textures: ?[]Texture = null,
    extensions: ?Extensions = null,
    extras: ?Extras = null,
};

//;

pub const GlTF_Parser = struct {
    const Self = @This();

    pub const Error = error{
        AssetInfoNotFound,
        NoVersionSpecified,
        GlTF_VersionNotSupported,
        InvalidAccessor,
        InvalidBuffer,
    };

    allocator: *Allocator,
    parser: json.Parser,

    pub fn init(allocator: *Allocator) Self {
        return .{
            .allocator = allocator,
            .parser = json.Parser.init(allocator, false),
        };
    }

    pub fn deinit(self: *Self) void {
        self.parser.deinit();
    }

    //;

    pub fn parseFromString(self: *Self, input: []const u8) !GlTF {
        var j = try self.parser.parse(input);
        defer j.deinit();

        const root = j.root;

        // TODO better error handling for if json objects arent the right type?
        // not a big deal as long as user cant supply thier own assets

        const j_asset = root.Object.get("asset") orelse return Error.AssetInfoNotFound;
        const version = j_asset.Object.get("version") orelse return Error.NoVersionSpecified;
        if (!std.mem.eql(u8, version.String, "2.0")) return Error.GlTF_VersionNotSupported;

        var ret = GlTF{
            .asset = .{
                .version = try self.allocator.dupe(u8, version.String),
            },
        };

        try parseAsset(self, &ret, j_asset);
        if (root.Object.get("accessors")) |jv| {
            try parseAccessors(self, &ret, jv);
        }
        if (root.Object.get("buffers")) |jv| {
            try parseBuffers(self, &ret, jv);
        }

        // TODO
        if (root.Object.get("extensionsUsed")) |exts| {}
        if (root.Object.get("extensionsRequired")) |exts| {}

        return ret;
    }

    pub fn freeParse(self: *Self, gltf: *GlTF) void {
        self.freeAsset(gltf);
        self.freeAccessors(gltf);
        self.freeBuffers(gltf);
    }

    //;

    fn parseAsset(self: *Self, gltf: *GlTF, j_asset: json.Value) !void {
        // TODO handle memory leaks
        if (j_asset.Object.get("copyright")) |jv| {
            gltf.asset.copyright = try self.allocator.dupe(u8, jv.String);
        }
        if (j_asset.Object.get("generator")) |jv| {
            gltf.asset.generator = try self.allocator.dupe(u8, jv.String);
        }
        if (j_asset.Object.get("minVersion")) |jv| {
            gltf.asset.min_version = try self.allocator.dupe(u8, jv.String);
        }
        if (j_asset.Object.get("extensions")) |jv| {
            gltf.asset.extensions = try jsonValueDeepClone(self.allocator, jv);
        }
        if (j_asset.Object.get("extras")) |jv| {
            gltf.asset.extras = try jsonValueDeepClone(self.allocator, jv);
        }
    }

    fn freeAsset(self: *Self, gltf: *GlTF) void {
        self.allocator.free(gltf.asset.version);
        if (gltf.asset.copyright) |str| self.allocator.free(str);
        if (gltf.asset.generator) |str| self.allocator.free(str);
        if (gltf.asset.min_version) |str| self.allocator.free(str);
        if (gltf.asset.extensions) |*ext| jsonValueFreeClone(self.allocator, ext);
        if (gltf.asset.extras) |*ext| jsonValueFreeClone(self.allocator, ext);
    }

    fn parseAccessors(self: *Self, gltf: *GlTF, j_accessors: json.Value) !void {
        const len = j_accessors.Array.items.len;
        gltf.accessors = try self.allocator.alloc(Accessor, len);
        for (j_accessors.Array.items) |jv, i| {
            const gl_type = jv.Object.get("componentType") orelse return Error.InvalidAccessor;
            const count = jv.Object.get("count") orelse return Error.InvalidAccessor;
            const data_type_str = (jv.Object.get("type") orelse return Error.InvalidAccessor).String;
            const data_type = if (std.mem.eql(u8, data_type_str, "SCALAR")) blk: {
                break :blk Accessor.DataType.Scalar;
            } else if (std.mem.eql(u8, data_type_str, "VEC2")) blk: {
                break :blk Accessor.DataType.Vec2;
            } else if (std.mem.eql(u8, data_type_str, "VEC3")) blk: {
                break :blk Accessor.DataType.Vec3;
            } else if (std.mem.eql(u8, data_type_str, "VEC4")) blk: {
                break :blk Accessor.DataType.Vec4;
            } else if (std.mem.eql(u8, data_type_str, "MAT2")) blk: {
                break :blk Accessor.DataType.Mat2;
            } else if (std.mem.eql(u8, data_type_str, "MAT3")) blk: {
                break :blk Accessor.DataType.Mat3;
            } else if (std.mem.eql(u8, data_type_str, "MAT4")) blk: {
                break :blk Accessor.DataType.Mat4;
            } else {
                return Error.InvalidAccessor;
            };

            var acc = &gltf.accessors.?[i];
            acc.* = .{
                .component_type = @intToEnum(Accessor.ComponentType, @intCast(c.GLenum, gl_type.Integer)),
                .count = @intCast(usize, count.Integer),
                .data_type = data_type,
            };

            if (jv.Object.get("bufferView")) |jv_| {
                acc.buffer_view = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("byteOffset")) |jv_| {
                acc.byte_offset = @intCast(usize, jv_.Integer);
            }
            if (jv.Object.get("normalized")) |jv_| {
                acc.normalized = jv_.Bool;
            }
            if (jv.Object.get("name")) |jv_| {
                acc.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                acc.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                acc.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeAccessors(self: *Self, gltf: *GlTF) void {
        if (gltf.accessors) |accs| {
            for (accs) |*acc| {
                if (acc.name) |name| self.allocator.free(name);
                if (acc.extensions) |*ext| jsonValueFreeClone(self.allocator, ext);
                if (acc.extras) |*ext| jsonValueFreeClone(self.allocator, ext);
            }
            self.allocator.free(accs);
        }
    }

    fn parseBuffers(self: *Self, gltf: *GlTF, j_buffers: json.Value) !void {
        const len = j_buffers.Array.items.len;
        gltf.buffers = try self.allocator.alloc(Buffer, len);
        for (j_buffers.Array.items) |jv, i| {
            const byte_length = jv.Object.get("byteLength") orelse return Error.InvalidBuffer;
            var buf = &gltf.buffers.?[i];
            buf.* = .{
                .byte_length = @intCast(usize, byte_length.Integer),
            };
            if (jv.Object.get("uri")) |jv_| {
                buf.uri = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("name")) |jv_| {
                buf.name = try self.allocator.dupe(u8, jv_.String);
            }
            if (jv.Object.get("extensions")) |jv_| {
                buf.extensions = try jsonValueDeepClone(self.allocator, jv_);
            }
            if (jv.Object.get("extras")) |jv_| {
                buf.extras = try jsonValueDeepClone(self.allocator, jv_);
            }
        }
    }

    fn freeBuffers(self: *Self, gltf: *GlTF) void {
        if (gltf.buffers) |bufs| {
            for (bufs) |*buf| {
                if (buf.uri) |uri| self.allocator.free(uri);
                if (buf.name) |name| self.allocator.free(name);
                if (buf.extensions) |*ext| jsonValueFreeClone(self.allocator, ext);
                if (buf.extras) |*ext| jsonValueFreeClone(self.allocator, ext);
            }
            self.allocator.free(bufs);
        }
    }

    // fn parseBuffers(self: *Self, gltf: *GlTF, j_buffers: json.Value) !void {}
    // fn freeBuffers(self: *Self, gltf: *GlTF) void {}
};

test "gltf" {
    const testing = std.testing;
    const suz = @import("content.zig").gltf.suzanne;
    var parser = GlTF_Parser.init(testing.allocator);
    defer parser.deinit();

    var gltf = try parser.parseFromString(suz);
    defer parser.freeParse(&gltf);

    std.log.warn("generator {}", .{gltf.asset.generator});
    std.log.warn("buf len   {}", .{gltf.buffers.?.len});
    std.log.warn("buf start {}", .{gltf.buffers.?[0].uri.?[0..15]});
}
