#version 140

// The last pass: the blurred background drawn back on the screen inside one
// pane's rounded outline, through the material's saturation, bent at the
// pane's rim, with a little grain against banding. From KWin's blur
// (onscreen_rounded.frag).

uniform sampler2D texUnit;
uniform mat4 colorMatrix;
uniform float offset;
uniform vec2 halfpixel;
uniform vec4 box;
uniform vec4 cornerRadius;
uniform float opacity;
uniform float noise;
// The rim: how wide it is in pixels (0 for none), how far it bends as a
// share of that, and how far apart the colors bend as a share of the bend.
uniform vec3 rim;
// One pixel of the screen in the texture's coordinates.
uniform vec2 texel;

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

// Which way is out from there: straight off the nearest side, or along the
// corner's own radius.
vec2 outward(vec2 position, vec2 center, vec2 extents, vec4 radius)
{
    vec2 p = position - center;
    float r = p.x > 0.0
        ? (p.y < 0.0 ? radius.y : radius.w)
        : (p.y < 0.0 ? radius.x : radius.z);
    vec2 q = abs(p) - extents + vec2(r);
    vec2 side = vec2(p.x < 0.0 ? -1.0 : 1.0, p.y < 0.0 ? -1.0 : 1.0);
    if (q.x > 0.0 && q.y > 0.0) {
        return normalize(q) * side;
    }
    return q.x > q.y ? vec2(side.x, 0.0) : vec2(0.0, side.y);
}

// The last upsampling of the blur, read at a place.
vec4 blurred(vec2 at)
{
    vec4 sum = texture(texUnit, at + vec2(-halfpixel.x * 2.0, 0.0) * offset);
    sum += texture(texUnit, at + vec2(-halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += texture(texUnit, at + vec2(0.0, halfpixel.y * 2.0) * offset);
    sum += texture(texUnit, at + vec2(halfpixel.x, halfpixel.y) * offset) * 2.0;
    sum += texture(texUnit, at + vec2(halfpixel.x * 2.0, 0.0) * offset);
    sum += texture(texUnit, at + vec2(halfpixel.x, -halfpixel.y) * offset) * 2.0;
    sum += texture(texUnit, at + vec2(0.0, -halfpixel.y * 2.0) * offset);
    sum += texture(texUnit, at + vec2(-halfpixel.x, -halfpixel.y) * offset) * 2.0;
    return sum / 12.0;
}

float grain(vec2 place)
{
    return fract(sin(dot(place, vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
}

void main(void)
{
    float f = sdfRoundedBox(vertex, box.xy, box.zw, cornerRadius);

    vec4 color;
    // How far into the rim this is: 0 where it begins, 1 at the pane's edge.
    float depth = rim.x > 0.0 ? clamp(1.0 + f / rim.x, 0.0, 1.0) : 0.0;
    if (depth > 0.0) {
        // A pane's edge is a lens: what shows there lies further out, the
        // more the nearer the edge (what lies past the pane's own edge is
        // its edge, drawn out). Red bends a little less than green, blue a
        // little more. The texture's rows run upward, the screen's down.
        vec2 bend = outward(vertex, box.xy, box.zw, cornerRadius) * (rim.y * rim.x * depth * depth);
        vec2 shift = vec2(bend.x, -bend.y) * texel;
        color = vec4(blurred(uv + shift * (1.0 - rim.z)).r,
                     blurred(uv + shift).g,
                     blurred(uv + shift * (1.0 + rim.z)).b,
                     1.0);
    } else {
        color = blurred(uv);
    }

    color = color * colorMatrix;
    color.rgb = max(color.rgb + vec3(grain(gl_FragCoord.xy) * noise), vec3(0.0));

    float df = fwidth(f);
    float coverage = 1.0 - clamp(0.5 + f / df, 0.0, 1.0);

    // What is behind glass is the finished picture: opaque.
    fragColor = vec4(color.rgb, 1.0) * (opacity * coverage);
}
