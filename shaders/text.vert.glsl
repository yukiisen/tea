#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoords;

uniform mat4 u_proj;

out vec2 vTexCoords;

void main() {
    gl_Position = u_proj * vec4(aPos, 1.0);
    vTexCoords = aTexCoords;
}
