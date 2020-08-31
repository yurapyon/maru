vec3 effect() {
    return _screen * _view * _model * vec3(_ext_vertex, 1.0);
}
