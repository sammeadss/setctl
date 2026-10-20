//
//  SetEntry.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/22/26.
//

import Foundation
import GRDB

/// A single logged set.
public struct SetEntry: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public var id: String = UUID().uuidString
    public var workoutExerciseId: String
    public var position: Int
    public var reps: Int
    public var weight: Double
    public var weightUnit: String
    public var rpe: Double?
    public var isWarmup: Bool
    public var isCompleted: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: String = UUID().uuidString,
        workoutExerciseId: String,
        position: Int,
        reps: Int,
        weight: Double,
        weightUnit: String,
        rpe: Double? = nil,
        isWarmup: Bool,
        isCompleted: Bool,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.workoutExerciseId = workoutExerciseId
        self.position = position
        self.reps = reps
        self.weight = weight
        self.weightUnit = weightUnit
        self.rpe = rpe
        self.isWarmup = isWarmup
        self.isCompleted = isCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
