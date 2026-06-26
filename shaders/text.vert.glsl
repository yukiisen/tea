#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoords;

uniform mat4 u_proj;
uniform mat4 u_view;

out vec2 vTexCoords;

void main() {
    gl_Position = u_proj * u_view * vec4(aPos, 1, 1.0);
    vTexCoords = aTexCoords;
}
