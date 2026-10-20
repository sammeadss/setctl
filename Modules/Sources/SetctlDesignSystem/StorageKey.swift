//
//  StorageKey.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/7/26.
//

/// `UserDefaults` keys for the display and haptics settings. Renaming a value resets users' saved settings.
public enum StorageKey {
    public static let scanlinesEnabled = "scanlinesEnabled"
    public static let hapticsEnabled = "hapticsEnabled"
    public static let highContrastEnabled = "highContrastEnabled"
    public static let scanlineMotionEnabled = "scanlineMotionEnabled"
}
