//
//  Scanlines.metal
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

#include <metal_stdlib>
using namespace metal;

[[ stitchable ]]
half4 scanlines(float2 position, half4 color, float time) {
    // A dark band rolls down the screen while overall brightness slowly pulses. At time 0 it is static.
    float roll = sin(position.y * 1.5 - time * 2.5) * 0.5 + 0.5;
    float breathe = sin(time * 0.6) * 0.22;
    half darken = half(clamp(mix(0.7, 1.0, roll) + breathe, 0.0, 1.0));
    return half4(color.rgb * darken, color.a);
}
