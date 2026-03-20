#version 330 core
out vec4 FragColor;
in vec2 texCoord;
in vec4 vertColor;

uniform sampler2D textureSampler;

void main()
{
    FragColor = texture(textureSampler, texCoord) * vertColor;
}
