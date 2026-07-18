#version 450 core

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec2 dst_pos;
layout (location = 3) in vec2 dst_center;
layout (location = 4) in vec2 dst_half_size;
layout (location = 5) in float corner_radius;
layout (location = 6) in float edge_softness;
layout (location = 7) in vec4 color_in;

layout (location = 0) out vec4 color_out;

layout (binding = 0) uniform sampler2D texture_in;

float RoundedRectSDF(vec2 sample_pos,
                     vec2 rect_center,
                     vec2 rect_half_size,
                     float r) {
    vec2 d2 = (abs(rect_center - sample_pos) -
               rect_half_size +
               vec2(r, r));
    return min(max(d2.x, d2.y), 0.0) + length(max(d2, 0.0)) -r;
}

void main() {
    float softness = edge_softness;
    vec2 softness_padding = vec2(max(0, softness*2-1),
                                 max(0, softness*2-1));

    float dist = RoundedRectSDF(dst_pos,
                                dst_center,
                                dst_half_size-softness_padding,
                                corner_radius);

    float sdf_factor = 1.f - smoothstep(0, 2*softness, dist);

    color_out = texture(texture_in, uv) * color_in * sdf_factor;
}
