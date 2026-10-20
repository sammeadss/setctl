//
//  Bloom.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

import SwiftUI

public extension View {
    /// Adds a glow by blending the brightest nearby pixels back over the view; `intensity` of 0 does nothing.
    func bloom(intensity: Double) -> some View {
        layerEffect(
            ShaderLibrary.bundle(.module).bloom(.float(intensity)),
            // Must cover the shader's sample radius or SwiftUI clips what it can read.
            maxSampleOffset: CGSize(width: 4, height: 4)
        )
    }
}
