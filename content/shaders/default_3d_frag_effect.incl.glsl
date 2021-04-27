vec4 effect() {
    return _base_color * texture2D(_tx_diffuse, _uv_coord);
}
