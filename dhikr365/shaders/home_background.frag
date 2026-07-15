#version 460 core

// ============================================================================
// home_background.frag — flowing organic background for the Home screen.
//
// Port of the reference WebGL shader (sin-wave colour field + drifting glow),
// recoloured for the Adhkaar 365 dark theme:
//   deep near-black green  →  #061414 (darker cousin of AppColors.bgDark)
//   deep teal              →  #1A2E2E (AppColors.bgTeal)
//   soft amber glow        →  #EC7F13 (AppColors.primary)
//
// The original followed the mouse; on touch devices the glow drifts by
// itself along a slow Lissajous path, so the background always feels alive.
//
// Uniform order matters — Dart sets them by index:
//   0: u_time  1: u_resolution.x  2: u_resolution.y
// ============================================================================

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform float u_time;
uniform vec2 u_resolution;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;

    // Autonomous focal point (replaces the mouse) — slow Lissajous drift.
    vec2 focal = vec2(
        0.5 + 0.35 * sin(u_time * 0.11),
        0.35 + 0.25 * cos(u_time * 0.07)
    );

    // Soft, flowing organic pattern — same math as the reference shader.
    float wave1 = sin(uv.x * 3.0 + u_time * 0.5) * 0.5 + 0.5;
    float wave2 = sin(uv.y * 4.0 - u_time * 0.3) * 0.5 + 0.5;
    float dist  = distance(uv, focal);
    float glow  = smoothstep(0.5, 0.0, dist) * 0.2;

    // Adhkaar 365 palette
    vec3 nearBlack = vec3(0.024, 0.078, 0.078); // #061414
    vec3 deepTeal  = vec3(0.102, 0.180, 0.180); // #1A2E2E
    vec3 softAmber = vec3(0.925, 0.498, 0.075); // #EC7F13

    // Blend: dark base breathing toward teal, amber warmth around the focal.
    vec3 color = mix(nearBlack, deepTeal, wave1 * wave2);
    color = mix(color, softAmber, glow * 0.30);

    // Gentle top-glow vignette — echoes the app's radial bgTeal→bgDark
    // gradients so the screen doesn't feel flat at the horizon.
    float topGlow = smoothstep(1.0, 0.0, uv.y) * 0.12;
    color += deepTeal * topGlow;

    fragColor = vec4(color, 1.0);
}
