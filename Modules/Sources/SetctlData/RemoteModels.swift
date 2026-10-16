//
//  RemoteModels.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation

struct RemoteWorkout: Codable, Equatable {
    var id: String
    var userId: String
    var startedAt: Date
    var endedAt: Date?
    var note: String?
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ workout: Workout, userId: String) {
        id = workout.id.lowercased()
        self.userId = userId.lowercased()
        startedAt = workout.startedAt
        endedAt = workout.endedAt
        note = workout.note
        createdAt = workout.createdAt
        updatedAt = workout.updatedAt
        deletedAt = workout.deletedAt
        serverUpdatedAt = nil
    }

    var local: Workout {
        Workout(
            id: id.uppercased(),
            startedAt: startedAt,
            endedAt: endedAt,
            note: note,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(endedAt, forKey: .endedAt)
        try container.encode(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deletedAt, forKey: .deletedAt)
    }
}

struct RemoteWorkoutExercise: Codable, Equatable {
    var id: String
    var userId: String
    var workoutId: String
    var exerciseId: String
    var position: Int
    var updatedAt: Date
    var deletedAt: Date?
    var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutId = "workout_id"
        case exerciseId = "exercise_id"
        case position
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ workoutExercise: WorkoutExercise, userId: String) {
        id = workoutExercise.id.lowercased()
        self.userId = userId.lowercased()
        workoutId = workoutExercise.workoutId.lowercased()
        exerciseId = workoutExercise.exerciseId.lowercased()
        position = workoutExercise.position
        updatedAt = workoutExercise.updatedAt
        deletedAt = workoutExercise.deletedAt
        serverUpdatedAt = nil
    }

    var local: WorkoutExercise {
        WorkoutExercise(
            id: id.uppercased(),
            workoutId: workoutId.uppercased(),
            exerciseId: exerciseId.uppercased(),
            position: position,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(workoutId, forKey: .workoutId)
        try container.encode(exerciseId, forKey: .exerciseId)
        try container.encode(position, forKey: .position)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deletedAt, forKey: .deletedAt)
    }
}

struct RemoteSetEntry: Codable, Equatable {
    var id: String
    var userId: String
    var workoutExerciseId: String
    var position: Int
    var reps: Int
    var weight: Double
    var weightUnit: String
    var rpe: Double?
    var isWarmup: Bool
    var isCompleted: Bool
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
    var serverUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case workoutExerciseId = "workout_exercise_id"
        case position
        case reps
        case weight
        case weightUnit = "weight_unit"
        case rpe
        case isWarmup = "is_warmup"
        case isCompleted = "is_completed"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
        case serverUpdatedAt = "server_updated_at"
    }

    init(_ set: SetEntry, userId: String) {
        id = set.id.lowercased()
        self.userId = userId.lowercased()
        workoutExerciseId = set.workoutExerciseId.lowercased()
        position = set.position
        reps = set.reps
        weight = set.weight
        weightUnit = set.weightUnit
        rpe = set.rpe
        isWarmup = set.isWarmup
        isCompleted = set.isCompleted
        createdAt = set.createdAt
        updatedAt = set.updatedAt
        deletedAt = set.deletedAt
        serverUpdatedAt = nil
    }

    var local: SetEntry {
        SetEntry(
            id: id.uppercased(),
            workoutExerciseId: workoutExerciseId.uppercased(),
            position: position,
            reps: reps,
            weight: weight,
            weightUnit: weightUnit,
            rpe: rpe,
            isWarmup: isWarmup,
            isCompleted: isCompleted,
            createdAt: createdAt,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(userId, forKey: .userId)
        try container.encode(workoutExerciseId, forKey: .workoutExerciseId)
        try container.encode(position, forKey: .position)
        try container.encode(reps, forKey: .reps)
        try container.encode(weight, forKey: .weight)
        try container.encode(weightUnit, forKey: .weightUnit)
        try container.encode(rpe, forKey: .rpe)
        try container.encode(isWarmup, forKey: .isWarmup)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(deletedAt, forKey: .deletedAt)
    }
}

protocol SyncRow: Codable, Equatable, Sendable {
    static var remoteTable: String { get }
    var serverUpdatedAt: Date? { get }
}

extension RemoteWorkout: SyncRow {
    static let remoteTable = "workouts"
}

extension RemoteWorkoutExercise: SyncRow {
    static let remoteTable = "workout_exercises"
}

extension RemoteSetEntry: SyncRow {
    static let remoteTable = "set_entries"
}
