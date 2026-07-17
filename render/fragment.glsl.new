#version 450 core

layout (location = 0) in vec4 vertex;
layout (location = 1) in vec2 uv;
layout (location = 2) in vec4 color_in;

layout (location = 0) out vec4 color_out;

layout (binding = 0) uniform sampler2D texture_in;

void main() {
    color_out = texture(texture_in, uv) * color_in;
}
