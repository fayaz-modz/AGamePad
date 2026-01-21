#include <flutter/runtime_effect.glsl>

// Uniforms passed from Dart
uniform vec2 uSize;           // Widget size
uniform float uIsCircle;      // 1.0 for circle, 0.0 for rounded rect

// Per-corner radii (topLeft, topRight, bottomRight, bottomLeft)
uniform vec4 uCornerRadii;

// Shadow 1 parameters
uniform vec4 uShadow1Color;   // RGBA color
uniform vec2 uShadow1Offset;  // Offset in pixels
uniform float uShadow1Blur;   // Blur radius
uniform float uShadow1Spread; // Spread radius

// Shadow 2 parameters (optional, set color alpha to 0 to disable)
uniform vec4 uShadow2Color;
uniform vec2 uShadow2Offset;
uniform float uShadow2Blur;
uniform float uShadow2Spread;

// Shadow 3 parameters (optional)
uniform vec4 uShadow3Color;
uniform vec2 uShadow3Offset;
uniform float uShadow3Blur;
uniform float uShadow3Spread;

// Shadow 4 parameters (optional)
uniform vec4 uShadow4Color;
uniform vec2 uShadow4Offset;
uniform float uShadow4Blur;
uniform float uShadow4Spread;

out vec4 fragColor;

// Anti-aliasing width in pixels
const float AA_WIDTH = 1.0;

// Signed distance function for a rounded rectangle with per-corner radii
// cornerRadii: (topLeft, topRight, bottomRight, bottomLeft)
float sdRoundedRectPerCorner(vec2 p, vec2 size, vec4 cornerRadii) {
    vec2 halfSize = size * 0.5;
    
    // Clamp all radii to not exceed half the minimum dimension
    float maxRadius = min(halfSize.x, halfSize.y);
    vec4 radii = min(cornerRadii, vec4(maxRadius));
    
    // Select the correct corner radius based on the point position
    float radius;
    vec2 cornerOffset;
    
    if (p.x < 0.0 && p.y < 0.0) {
        // Top-left corner
        radius = radii.x;
        cornerOffset = halfSize - vec2(radius);
    } else if (p.x >= 0.0 && p.y < 0.0) {
        // Top-right corner
        radius = radii.y;
        cornerOffset = halfSize - vec2(radius);
    } else if (p.x >= 0.0 && p.y >= 0.0) {
        // Bottom-right corner
        radius = radii.z;
        cornerOffset = halfSize - vec2(radius);
    } else {
        // Bottom-left corner
        radius = radii.w;
        cornerOffset = halfSize - vec2(radius);
    }
    
    // Work in positive quadrant
    vec2 q = abs(p);
    
    // Distance to the rounded rectangle
    vec2 d = q - cornerOffset;
    
    // If we're in the corner region (both x and y exceed the corner offset)
    if (d.x > 0.0 && d.y > 0.0) {
        // Circular corner distance
        return length(d) - radius;
    } else {
        // Edge distance (max of the two for box)
        return max(q.x - halfSize.x, q.y - halfSize.y);
    }
}

// Signed distance function for a circle
float sdCircle(vec2 p, float radius) {
    return length(p) - radius;
}

// Get the signed distance based on shape type
float getShapeSDF(vec2 p, vec2 size, vec4 cornerRadii, float isCircle) {
    if (isCircle > 0.5) {
        float radius = min(size.x, size.y) * 0.5;
        return sdCircle(p, radius);
    } else {
        return sdRoundedRectPerCorner(p, size, cornerRadii);
    }
}

// Scale corner radii when shrinking by spread
vec4 scaleCornerRadii(vec4 radii, float spreadRadius) {
    // Reduce each radius by the spread amount, clamped to 0
    return max(radii - spreadRadius, vec4(0.0));
}

// Compute inner shadow contribution for a single shadow with anti-aliasing
vec4 computeInnerShadow(
    vec2 fragCoord,
    vec2 size,
    vec4 cornerRadii,
    float isCircle,
    vec4 shadowColor,
    vec2 shadowOffset,
    float blurRadius,
    float spreadRadius
) {
    if (shadowColor.a < 0.001) {
        return vec4(0.0);
    }
    
    // Center coordinates
    vec2 center = size * 0.5;
    vec2 p = fragCoord - center;
    
    // Get base shape distance
    float baseDist = getShapeSDF(p, size, cornerRadii, isCircle);
    
    // Anti-aliased shape boundary check
    // Smooth transition at the shape edge for anti-aliasing
    float shapeMask = 1.0 - smoothstep(-AA_WIDTH, 0.0, baseDist);
    
    if (shapeMask < 0.001) {
        return vec4(0.0);
    }
    
    // Calculate shadow edge position
    vec2 shadowP = p - shadowOffset;
    
    // Adjust size for spread (inner shadow shrinks the shape)
    vec2 shrunkSize = size - spreadRadius * 2.0;
    shrunkSize = max(shrunkSize, vec2(1.0)); // Prevent zero/negative size
    
    // Scale corner radii - reduce by spread amount
    vec4 shrunkRadii = scaleCornerRadii(cornerRadii, spreadRadius);
    
    // Distance from the shrunk/offset shadow edge
    float shadowDist = getShapeSDF(shadowP, shrunkSize, shrunkRadii, isCircle);
    
    // Compute shadow factor with anti-aliased edge
    float shadowFactor;
    
    if (blurRadius > 0.0) {
        // Smooth blur transition with AA
        float aaBlur = max(blurRadius, AA_WIDTH);
        shadowFactor = smoothstep(-aaBlur, aaBlur, shadowDist);
    } else {
        // Hard edge with anti-aliasing
        shadowFactor = smoothstep(-AA_WIDTH, AA_WIDTH, shadowDist);
    }
    
    // Apply shape mask for clean edges
    return vec4(shadowColor.rgb, shadowColor.a * shadowFactor * shapeMask);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    
    // Compute all shadows
    vec4 shadow1 = computeInnerShadow(
        fragCoord, uSize, uCornerRadii, uIsCircle,
        uShadow1Color, uShadow1Offset, uShadow1Blur, uShadow1Spread
    );
    
    vec4 shadow2 = computeInnerShadow(
        fragCoord, uSize, uCornerRadii, uIsCircle,
        uShadow2Color, uShadow2Offset, uShadow2Blur, uShadow2Spread
    );
    
    vec4 shadow3 = computeInnerShadow(
        fragCoord, uSize, uCornerRadii, uIsCircle,
        uShadow3Color, uShadow3Offset, uShadow3Blur, uShadow3Spread
    );
    
    vec4 shadow4 = computeInnerShadow(
        fragCoord, uSize, uCornerRadii, uIsCircle,
        uShadow4Color, uShadow4Offset, uShadow4Blur, uShadow4Spread
    );
    
    // Blend shadows together using standard alpha compositing (over operator)
    vec4 result = vec4(0.0);
    
    // Apply shadow 1
    if (shadow1.a > 0.001) {
        result.rgb = result.rgb * (1.0 - shadow1.a) + shadow1.rgb * shadow1.a;
        result.a = result.a + shadow1.a * (1.0 - result.a);
    }
    
    // Apply shadow 2
    if (shadow2.a > 0.001) {
        result.rgb = result.rgb * (1.0 - shadow2.a) + shadow2.rgb * shadow2.a;
        result.a = result.a + shadow2.a * (1.0 - result.a);
    }
    
    // Apply shadow 3
    if (shadow3.a > 0.001) {
        result.rgb = result.rgb * (1.0 - shadow3.a) + shadow3.rgb * shadow3.a;
        result.a = result.a + shadow3.a * (1.0 - result.a);
    }
    
    // Apply shadow 4
    if (shadow4.a > 0.001) {
        result.rgb = result.rgb * (1.0 - shadow4.a) + shadow4.rgb * shadow4.a;
        result.a = result.a + shadow4.a * (1.0 - result.a);
    }
    
    fragColor = result;
}
