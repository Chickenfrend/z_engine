#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in mat4 instanceModel;
layout (location = 6) in vec2 instanceUVOffset;
layout (location = 7) in vec2 instanceUVSize;
layout (location = 8) in vec4 instanceColor;

out vec2 texCoord;
out vec4 vertColor;
uniform mat4 projection;
uniform mat4 view;

void main()
{
    gl_Position = projection * view * instanceModel * vec4(aPos, 1.0);
    texCoord = instanceUVOffset + aTexCoord * instanceUVSize;
    vertColor = instanceColor;
}
