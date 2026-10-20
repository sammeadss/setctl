//
//  Colors.swift
//  SetctlModules
//
//  Created by Samuel Meads on 6/24/26.
//

import SwiftUI

extension Color {
    /// Creates a color from a 24-bit RGB value.
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

/// The terminal palette: phosphor green on black. Amber marks warnings and in-progress accents; red is for destructive
/// actions only.
public enum Palette {
    public static let black = Color(hex: 0x000000)
    public static let green = Color(hex: 0x00FF66)

    /// Secondary text; steps brighter when high contrast is on.
    public static var greenDim: Color {
        isHighContrastEnabled ? Color(hex: 0x8FE6AD) : Color(hex: 0x4F9E6A)
    }

    /// Hairlines, borders, and disabled states; steps brighter when high contrast is on.
    public static var greenFaint: Color {
        isHighContrastEnabled ? Color(hex: 0x4F9E6A) : Color(hex: 0x1E4D33)
    }

    public static let amber = Color(hex: 0xFFB000)
    public static let red = Color(hex: 0xFF5C5C)

    private static var isHighContrastEnabled: Bool {
        UserDefaults.standard.bool(forKey: StorageKey.highContrastEnabled)
    }
}
