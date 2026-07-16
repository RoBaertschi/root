#version 460 core

layout (location = 1) uniform vec2 res;

layout (location = 0) in vec2 rect_00;
layout (location = 1) in vec2 rect_11;
layout (location = 2) in vec4 color_in;

layout (location = 0) out vec4 color_out;

const vec2 vertices[4] = vec2[](
    vec2(-1, -1),
    vec2(-1, +1),
    vec2(+1, -1),
    vec2(+1, +1)
);

void main() {
    vec2 dst_half_size = (rect_11 - rect_00) / 2;
    vec2 dst_center    = (rect_11 + rect_00) / 2;
    vec2 dst_pos       = (vertices[gl_VertexID] * dst_half_size + dst_center);

    gl_Position = vec4(
        2 * dst_pos.x / res.x - 1,
        2 * dst_pos.y / res.y - 1,
        0,
        1
    );
    color_out = color_in;
}
