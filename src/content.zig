pub const images = struct {
    pub const mahou = @embedFile("../content/mahou.jpg");
    pub const codepage437 = @embedFile("../content/Codepage437.png");
};

pub const shaders = struct {
    pub const default_vert = @embedFile("../content/shaders/default_vert.glsl");
    pub const default_frag = @embedFile("../content/shaders/default_frag.glsl");

    pub const default_vert_effect = @embedFile("../content/shaders/default_vert_effect.incl.glsl");
    pub const default_frag_effect = @embedFile("../content/shaders/default_frag_effect.incl.glsl");
    pub const default_spritebatch_vert = @embedFile("../content/shaders/spritebatch_vert.incl.glsl");
    pub const default_spritebatch_frag = @embedFile("../content/shaders/spritebatch_frag.incl.glsl");

    pub const default_3d_vert = @embedFile("../content/shaders/default_3d_vert.glsl");
    pub const default_3d_frag = @embedFile("../content/shaders/default_3d_frag.glsl");
    pub const default_3d_vert_effect = @embedFile("../content/shaders/default_3d_vert_effect.incl.glsl");
    pub const default_3d_frag_effect = @embedFile("../content/shaders/default_3d_frag_effect.incl.glsl");
};

pub const gltf = struct {
    pub const suzanne = @embedFile("../content/gltf/suzanne.gltf");
};
