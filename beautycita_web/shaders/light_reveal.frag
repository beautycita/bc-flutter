#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniforms
uniform vec2 uSize;        // canvas size
uniform vec2 uLightPos;    // light source position (normalized 0-1)
uniform float uRadius;     // light radius (normalized)
uniform float uSoftness;   // edge softness
uniform vec3 uLightColor;  // light tint (RGB 0-1)
uniform float uAmbient;    // minimum ambient light (0-1)

out vec4 fragColor;

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / uSize;

    // Distance from light source
    vec2 lightUV = uLightPos;
    float aspect = uSize.x / uSize.y;
    vec2 corrected = vec2((uv.x - lightUV.x) * aspect, uv.y - lightUV.y);
    float dist = length(corrected);

    // Smooth falloff from light center
    float light = smoothstep(uRadius + uSoftness, uRadius * 0.3, dist);

    // Clamp to ambient minimum
    light = max(light, uAmbient);

    // Apply light color tint
    vec3 color = mix(vec3(0.0), uLightColor, light);

    // Output: white with alpha = light intensity
    // This will be used as a mask over the content
    fragColor = vec4(color, light);
}
