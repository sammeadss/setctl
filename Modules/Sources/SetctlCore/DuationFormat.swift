//
//  DuationFormat.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/30/26.
//

import Foundation

/// Formats elapsed time for clocks and lists.
public enum DurationFormat {
    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let remainder = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainder)
        }
        return String(format: "%d:%02d", minutes, remainder)
    }
}
