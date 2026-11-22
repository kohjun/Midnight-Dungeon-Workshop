// shaders/title_bolt.glsl
// 좌측 하늘 갈래 번개 깊이 차폐 셰이더: 전경 고목(depth > 0.24)과 공방 뒤로 자연스럽게 가려지게 처리한다.

extern Image u_depth;
extern vec4 u_rect;
extern vec2 u_mouse;
extern vec2 u_parallax;
extern number u_zoom;
extern number u_bolt_depth;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
    vec2 raw = (screen - u_rect.xy) / u_rect.zw;
    vec2 base_uv = (raw - 0.5) / u_zoom + 0.5;
    vec2 p_dir = u_mouse * u_parallax;
    float d0 = Texel(u_depth, clamp(base_uv + p_dir * (u_bolt_depth - 0.5), 0.001, 0.999)).r;
    float d_near = Texel(u_depth, clamp(base_uv + p_dir * 0.36, 0.001, 0.999)).r;
    float occ = max(d0, d_near * step(0.62, d_near));
    float vis = smoothstep(0.26, 0.18, occ);
    if (vis < 0.02) { discard; }
    return vec4(color.rgb, color.a * vis);
}
