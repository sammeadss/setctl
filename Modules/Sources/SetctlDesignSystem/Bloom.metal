//
//  Bloom.metal
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

[[ stitchable ]]
half4 bloom(float2 position, SwiftUI::Layer layer, float intensity) {
    half4 color = layer.sample(position);
    if (intensity <= 0.0) {
        return color;
    }

    half4 glow = half4(0.0);
    // Keep within `maxSampleOffset` in Bloom.swift.
    float radius = 3.0;
    for (float dx = -radius; dx <= radius; dx += 1.0) {
        for (float dy = -radius; dy <= radius; dy += 1.0) {
            glow = max(glow, layer.sample(position + float2(dx, dy)));
        }
    }
    return color + glow * half(intensity);
}
