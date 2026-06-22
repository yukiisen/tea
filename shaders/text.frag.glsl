#version 330 core

uniform sampler2D u_atlas;
uniform vec4 u_color;
uniform float u_pxRange;

in vec2 vTexCoords;

out vec4 FragColor;

float median(float r, float g, float b) {
    return max(min(r, g), min(max(r, g), b));
}

void main() {
    vec3 msd = texture(u_atlas, vTexCoords).rgb;
    float sd = median(msd.r, msd.g, msd.b);
    float screenPxDist = u_pxRange * (sd - 0.5);
    float opacity = clamp(screenPxDist + 0.5, 0.0, 1.0);
    FragColor = vec4(u_color.rgb, u_color.a * opacity);
}
