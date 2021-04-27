#version 330 core

layout (location = 0) in vec3 _ext_vertex;
layout (location = 1) in vec2 _ext_uv;
layout (location = 2) in vec3 _ext_normal;

// basic
uniform mat4 _projection;
uniform mat4 _view;
uniform mat4 _model;
uniform float _time;
uniform int _flip_uvs;

out vec2 _uv_coord;
out float _tm;
out vec3 _normal;

@

void main() {
    _uv_coord = _flip_uvs != 0 ? vec2(_ext_uv.x, 1 - _ext_uv.y) : _ext_uv;
    _tm = _time;
    _normal = _ext_normal;
    gl_Position = effect();
}
