//
//  Typography.swift
//  SetctlModules
//
//  Created by Samuel Meads on 6/24/26.
//

import SwiftUI

/// The type scale. Everything is monospaced; `hero` and `title` use the bundled VT323 face and scale with Dynamic Type
/// relative to the text style they name.
public enum Typography {
    public static let hero = Font.custom("VT323-Regular", size: 56, relativeTo: .largeTitle)
    public static let title = Font.custom("VT323-Regular", size: 32, relativeTo: .title)
    public static let headline = Font.system(.headline, design: .monospaced).weight(.regular)
    public static let body = Font.system(.body, design: .monospaced)
    public static let label = Font.system(.footnote, design: .monospaced)
    public static let caption = Font.system(.caption2, design: .monospaced)
}
