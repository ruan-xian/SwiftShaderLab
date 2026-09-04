#include <metal_stdlib>
using namespace metal;

static float sampleTable(device const float *samples, int count, float coordinate) {
    if (count <= 0) {
        return 0.0;
    }
    if (count == 1) {
        return samples[0];
    }

    float scaledIndex = clamp(coordinate, 0.0, 1.0) * float(count - 1);
    int lowerIndex = int(floor(scaledIndex));
    int upperIndex = min(lowerIndex + 1, count - 1);
    return mix(samples[lowerIndex], samples[upperIndex], fract(scaledIndex));
}

static half4 sampleGradient(
    device const float *locations,
    int locationCount,
    device const half4 *colors,
    int colorCount,
    float coordinate
) {
    int count = min(locationCount, colorCount);
    if (count <= 0) {
        return half4(1.0);
    }
    if (count == 1 || coordinate <= locations[0]) {
        return colors[0];
    }

    for (int index = 1; index < count; ++index) {
        if (coordinate <= locations[index]) {
            float width = max(locations[index] - locations[index - 1], 0.000001);
            float progress = clamp((coordinate - locations[index - 1]) / width, 0.0, 1.0);
            return mix(colors[index - 1], colors[index], half(progress));
        }
    }

    return colors[count - 1];
}

[[ stitchable ]] half4 lambertRadialProfile(
    float2 position,
    half4 sourceColor,
    float2 size,
    float gradientAngle,
    device const float *gradientLocations,
    int gradientLocationCount,
    device const half4 *gradientColors,
    int gradientColorCount,
    float lightAngle,
    float lightDistance,
    float lightDepth,
    float lightBrightness,
    half4 lightColor,
    float ambientStrength,
    half4 ambientColor,
    device const float *profileHeights,
    int profileHeightCount,
    device const float *profileDerivatives,
    int profileDerivativeCount
) {
    float radiusInPoints = max(min(size.x, size.y) * 0.5, 0.000001);
    float2 center = size * 0.5;
    // Shader-space angles use +x to the right, +y upward, and increase counterclockwise.
    float2 surfaceXY = float2(
        (position.x - center.x) / radiusInPoints,
        (center.y - position.y) / radiusInPoints
    );
    float radius = length(surfaceXY);

    if (radius > 1.0 || sourceColor.a <= 0.0h) {
        return half4(0.0);
    }

    float2 gradientDirection = float2(cos(gradientAngle), sin(gradientAngle));
    float gradientCoordinate = clamp(dot(surfaceXY, gradientDirection) * 0.5 + 0.5, 0.0, 1.0);
    half4 gradientSample = sampleGradient(
        gradientLocations,
        gradientLocationCount,
        gradientColors,
        gradientColorCount,
        gradientCoordinate
    );

    float height = clamp(
        sampleTable(profileHeights, profileHeightCount, radius),
        -10000.0,
        10000.0
    );
    float derivativeRadius = radius;
    if (profileDerivativeCount > 1) {
        // Stay one sample inside the rim so a vertical endpoint tangent remains steep.
        derivativeRadius = min(radius, float(profileDerivativeCount - 2) / float(profileDerivativeCount - 1));
    }
    float slope = clamp(
        sampleTable(profileDerivatives, profileDerivativeCount, derivativeRadius),
        -10000.0,
        10000.0
    );

    float2 radialDirection = radius > 0.000001 ? surfaceXY / radius : float2(0.0);
    float3 normal = normalize(float3(-slope * radialDirection, 1.0));

    float2 lightDirectionXY = float2(cos(lightAngle), sin(lightAngle));
    float3 lightPosition = float3(lightDirectionXY * lightDistance, lightDepth);
    float3 toLight = lightPosition - float3(surfaceXY, height);
    float lightVectorLength = length(toLight);
    float3 directionToLight = lightVectorLength > 0.000001
        ? toLight / lightVectorLength
        : float3(0.0, 0.0, 1.0);
    float lambert = max(dot(normal, directionToLight), 0.0);

    half3 illumination = ambientColor.rgb * half(ambientStrength)
        + lightColor.rgb * half(lightBrightness * lambert);
    half alpha = sourceColor.a;
    return half4(gradientSample.rgb * illumination * alpha, alpha);
}
