// shaders/foil.glsl
// 강화 +5 이상 유물 아이콘 위로 흐르는 포일 광택 (ui/Foil 이 가산 혼합으로 아이콘을 한 번 더 그릴 때 건다).
// 색(tint)은 강화 등급: +5 황금 · +7 자홍 룬 · +9 심연 신화 (data/forge.lua 의 tiers).
// 텍스처 알파(스프라이트) 또는 도형 자체가 마스크가 된다. 좌표는 아이콘 중심(origin)·크기(size) 기준으로 정규화한다.
//   time     : 초
//   origin   : 아이콘 중심의 화면 픽셀 좌표
//   size     : 아이콘 한 변의 화면 픽셀 크기
//   strength : 0~1 광택 세기 (강화 단계가 높을수록 세다)
//   speed    : 광택 띠가 지나가는 속도 (회/초)

extern number time;
extern vec2 origin;
extern number size;
extern number strength;
extern number speed;
extern vec3 tint;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen)
{
    float mask = Texel(tex, uv).a * color.a;
    vec2 p = (screen - origin) / size;                  // 아이콘 안 -0.5 ~ 0.5
    float diagonal = p.x * 0.75 + p.y * 0.65;
    float sweep = mix(-1.2, 1.2, fract(time * speed));
    float band = 1.0 - smoothstep(0.0, 0.14, abs(diagonal - sweep));
    float shimmer = 0.5 + 0.5 * sin((p.x - p.y) * 22.0 + time * 4.0);
    float rim = smoothstep(0.25, 0.5, length(p));
    vec3 gold = tint;
    vec3 white = vec3(1.0, 0.97, 0.85);
    vec3 glow = mix(gold, white, band) * (band * 0.95 + shimmer * 0.14 + rim * 0.12);
    return vec4(glow, mask * strength);
}
