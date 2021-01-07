const std = @import("std");
const ArrayList = std.ArrayList;

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

//;

pub const Buffer = struct {
    //;
};

pub const BufferView = struct {
    //;
};

pub const Accessor = struct {
    //;
};

//;

pub const Texture = struct {
    image: *Image,
    sampler: *Sampler,
};

pub const Image = struct {
    //;
};

pub const Sampler = struct {
    //;
};

//;

pub const Primitive = struct {
    mode: c.GLenum,
};

pub const Mesh = struct {
    primitives: ArrayList(*Primitive)
};

pub const Camera = struct {
    const Self = @This();

    const Data = union(enum) {
        Perspective: struct {
            aspect_ratio: f32,
            yfov: f32,
            zfar: f32,
            znear: f32,
        },

        Orthographic: struct {
            xmag: f32,
            ymag: f32,
            zfar: f32,
            znear: f32,
        },
    };

    data: Data
};

pub const Node = struct {
    children: ArrayList(*Node),
    matrix: ?Mat4,
    transform: ?Transform3d,
    mesh: ?*Mesh,
    camera: ?*Camera,
};

pub const Scene = struct {
    nodes: ArrayList(*Node),
};

pub const glTF = struct {
    default_scene: *Scene,
    scenes: ArrayList(Scene),
    nodes: ArrayList(Node),

    textures: ArrayList(Texture),
    images: ArrayList(Image),
    samplers: ArrayList(Sampler),
};
