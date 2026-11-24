#version 140

// The last pass: the blurred background drawn back on the screen inside one
// pane's rounded outline, through the material's saturation, with a little
// grain against banding. From KWin's blur (onscreen_rounded.frag).

uniform sampler2D texUnit;
uniform mat4 colorMatrix;
uniform float offset;
uniform vec2 halfpixel;
uniform vec4 box;
uniform vec4 cornerRadius;
uniform float opacity;
uniform float noise;

in vec2 uv;
in vec2 vertex;

out vec4 fragColor;

// KWin's (opengl/sdf.glsl): how far outside a rounded box a place is.
float sdfRoundedBox(vec2 position, vec2 center, vec2 extents, vec4 radius)
{
    vec2 p = position - center;
    float r = p.x > 0.0
        ? (p.y < 0.0 ? radius.y : radius.w)
        : (p.y < 0.0 ? radius.x : radius.z);
    vec2 q = abs(p) - extents + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

float grain(vec2 place)
{
    return fract(sin(dot(place, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

void main(void)
{
    vec4 sum = texture(texUnit, uv + vec2(-halfpixel.x * 2.0, 0.0) * offset);
    sum += texture(texUnit, uv + vec2(-halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += texture(texUnit, uv + vec2(0.0, halfpixel.y * 2.0) * offset);
    sum += texture(texUnit, uv + vec2(halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += texture(texUnit, uv + vec2(halfpixel.x * 2.0, 0.0) * offset);
    sum += texture(texUnit, uv + vec2(halfpixel.x, -halfpixel.y) * offset) * 2.0;
    sum += texture(texUnit, uv + vec2(0.0, -halfpixel.y * 2.0) * offset);
    sum += texture(texUnit, uv + vec2(-halfpixel.x, -halfpixel.y) * offset) * 2.0;

    vec4 color = (sum / 12.0) * colorMatrix;
    color.rgb = max(color.rgb + vec3(grain(gl_FragCoord.xy) * noise), vec3(0.0));

    float f = sdfRoundedBox(vertex, box.xy, box.zw, cornerRadius);
    float df = fwidth(f);
    float coverage = 1.0 - clamp(0.5 + f / df, 0.0, 1.0);

    // What is behind glass is the finished picture: opaque.
    fragColor = vec4(color.rgb, 1.0) * (opacity * coverage);
}
