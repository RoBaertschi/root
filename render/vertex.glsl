#version 460 core

layout (location = 1) uniform vec2 res;

layout (location = 0) in vec2 dst_00;
layout (location = 1) in vec2 dst_11;
layout (location = 2) in vec2 src_00;
layout (location = 3) in vec2 src_11;
layout (location = 4) in vec4 color_in;

layout (location = 0) out vec4 vertex;
layout (location = 1) out vec2 uv;
layout (location = 2) out vec4 color_out;

layout (binding = 0) uniform sampler2D texture_in;

const vec2 vertices[4] = vec2[](
    vec2(-1, -1),
    vec2(-1, +1),
    vec2(+1, -1),
    vec2(+1, +1));

void main() {
    vec2 dst_half_size = (dst_11 - dst_00) / 2;
    vec2 dst_center    = (dst_11 + dst_00) / 2;
    vec2 dst_pos       = (vertices[gl_VertexID] * dst_half_size + dst_center);

    vec2 src_half_size = (src_11 - src_00) / 2;
    vec2 src_center    = (src_11 + src_00) / 2;
    vec2 src_pos       = (vertices[gl_VertexID] * src_half_size + src_center);

    vertex = vec4(
        2 * dst_pos.x / res.x - 1,
        1 - 2 * dst_pos.y / res.y,
        0,
        1);
    gl_Position = vertex;

    ivec2 texture_size = textureSize(texture_in, 0);

    uv = vec2(
        src_pos.x / texture_size.x,
        src_pos.y / texture_size.y);

    color_out = color_in;
}
