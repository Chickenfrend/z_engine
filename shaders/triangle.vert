#version 450

layout(push_constant) uniform PushConstants {
    vec2 offset;
} push;

layout(location = 0) in vec2 inPosition;
layout(location = 1) in vec3 inColor;

layout(location = 0) out vec3 fragColor;

void main() {
    gl_Position = vec4(inPosition + push.offset, 0.0, 1.0);
    fragColor = inColor;
}