#version 450 core

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec2 dst_pos;
layout (location = 3) in vec2 dst_center;
layout (location = 4) in vec2 dst_half_size;
layout (location = 5) in float corner_radius;
layout (location = 6) in float edge_softness;
layout (location = 7) in float border_thickness;
layout (location = 8) in vec4 color_in;

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

    float border_factor = 1.f;
    if (border_thickness != 0) {
        vec2 interior_half_size = dst_half_size - vec2(border_thickness);

        float interior_radius_reduce_f = min(interior_half_size.x/dst_half_size.x,
                                             interior_half_size.y/dst_half_size.y);
        float interior_corner_radius = (corner_radius * interior_radius_reduce_f * interior_radius_reduce_f);

        float inside_d = RoundedRectSDF(dst_pos,
                                        dst_center,
                                        interior_half_size-softness_padding,
                                        interior_corner_radius);

        float inside_f = smoothstep(0, 2*softness, inside_d);
        border_factor = inside_f;
    }

    color_out = color_in * texture(texture_in, uv) * sdf_factor * border_factor;
}
