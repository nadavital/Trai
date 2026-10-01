#include <metal_stdlib>
using namespace metal;

// Lighting follows the same moving surface equation as NutritionFillSurface.
[[ stitchable ]] half4 traiNutritionCurrent(
    float2 position,
    half4 source,
    float2 size,
    half4 tint,
    float time,
    float level
) {
    float2 uv = position / size;
    float wave = sin(uv.x * 6.2831853f + time * 1.2f) / size.y;
    float surface = 1.0f - level + wave;
    float depth = clamp((uv.y - surface) / max(level, 0.001f), 0.0f, 1.0f);
    float rim = exp(-abs(uv.y - surface) * size.y / 3.0f);
    float current = sin(uv.x * 5.0f + depth * 3.0f + time * 0.35f) * 0.5f + 0.5f;
    float ribbonCenter = 0.24f + sin(uv.x * 4.0f - time * 0.35f) * 0.12f;
    float ribbon = exp(-pow((depth - ribbonCenter) * 7.0f, 2.0f));
    float3 color = float3(tint.rgb) * (0.84f + current * 0.14f + depth * 0.05f);
    color = mix(color, float3(1.0f), rim * 0.34f + ribbon * 0.17f);
    half alpha = source.a * 0.86h;
    return half4(half3(clamp(color, 0.0f, 1.0f)) * alpha, alpha);
}
