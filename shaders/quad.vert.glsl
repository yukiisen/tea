#version 330 core
layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTexCoords;
layout (location = 2) in vec3 aNormal;

uniform mat4 u_model;
uniform mat4 u_view;
uniform mat4 u_proj;

out vec2 TexCoords;

void main() {
    gl_Position = u_proj * u_view * u_model * vec4(aPos, 1.0);
    TexCoords = aTexCoords;
}
