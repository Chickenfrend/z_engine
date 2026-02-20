#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in mat4 instanceModel;

out vec2 texCoord;
uniform mat4 projection;

void main()
{
    gl_Position = projection * instanceModel * vec4(aPos, 1.0);
    texCoord = aTexCoord;
}
