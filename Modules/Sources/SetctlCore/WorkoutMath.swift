//
//  WorkoutMath.swift
//  SetctlModules
//
//  Created by Samuel Meads on 8/5/26.
//

/// Math for workout data.
public enum WorkoutMath {
    /// The sum of reps × weight across `sets`.
    ///
    /// Weights are summed as given, so every set must use the same unit.
    public static func totalVolume(of sets: [(reps: Int, weight: Double)]) -> Double {
        sets.reduce(0) { total, set in
            total + Double(set.reps) * set.weight
        }
    }
}
