vec4 effect() {
    return _projection * _view * _model * vec4(_ext_vertex, 1.0);
}
