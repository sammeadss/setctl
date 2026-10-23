//
//  WeightUnit.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/23/26.
//

/// Unit weights are shown and entered in. Weights are always stored in kilograms; views convert at the edge.
public enum WeightUnit: String, CaseIterable, Sendable {
    case kg
    case lb

    private static let poundsPerKilogram = 2.2046226218

    /// Converts a stored weight in kilograms to this unit.
    public func fromKilograms(_ kilograms: Double) -> Double {
        switch self {
        case .kg:
            kilograms
        case .lb:
            kilograms * Self.poundsPerKilogram
        }
    }

    /// Converts a weight in this unit to the kilograms that get stored.
    public func toKilograms(_ value: Double) -> Double {
        switch self {
        case .kg:
            value
        case .lb:
            value / Self.poundsPerKilogram
        }
    }
}
