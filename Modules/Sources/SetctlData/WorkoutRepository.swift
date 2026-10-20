//
//  WorkoutRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/22/26.
//

import Foundation
import GRDB
import SetctlCore

/// Reads and writes workouts together with their exercises and sets.
public struct WorkoutRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func save(_ workout: Workout) throws {
        try database.write { db in
            try workout.save(db)
        }
    }

    public func fetchWorkout(id: String) throws -> Workout? {
        try database.read { db in
            try Workout.fetchOne(db, id: id)
        }
    }

    /// Saves the workout, its exercises, and its sets in one transaction; failure never leaves half-saved workout.
    public func save(_ details: WorkoutDetails) throws {
        try database.write { db in
            try details.workout.save(db)
            for exercise in details.exercises {
                try exercise.workoutExercise.save(db)
                for set in exercise.sets {
                    try set.save(db)
                }
            }
        }
    }

    /// Returns the workout even if it is soft-deleted; its exercises and sets exclude soft-deleted rows.
    public func fetchDetails(id: String) throws -> WorkoutDetails? {
        try database.read { db in
            try loadDetails(id: id, in: db)
        }
    }

    private func loadDetails(id: String, in db: Database) throws -> WorkoutDetails? {
        guard let workout = try Workout.fetchOne(db, id: id) else {
            return nil
        }

        let workoutExercises = try WorkoutExercise
            .filter(Column("workoutId") == id)
            .filter(Column("deletedAt") == nil)
            .order(Column("position"))
            .fetchAll(db)

        var exercises: [WorkoutExerciseWithSets] = []
        for we in workoutExercises {
            let sets = try SetEntry
                .filter(Column("workoutExerciseId") == we.id)
                .filter(Column("deletedAt") == nil)
                .order(Column("position"))
                .fetchAll(db)
            exercises.append(WorkoutExerciseWithSets(workoutExercise: we, sets: sets))
        }

        return WorkoutDetails(workout: workout, exercises: exercises)
    }

    /// Returns the unfinished workout to resume, if any.
    ///
    /// Unfinished workouts idle for longer than `staleAfter` are closed as a side effect; they are ended at their last
    /// set or soft-deleted if they have none. Logged sets are never discarded.
    public func resolveUnfinishedWorkout(
        now: Date = Date(),
        staleAfter: TimeInterval = 12 * 60 * 60
    ) throws -> WorkoutDetails? {
        try database.write { db in
            let unfinished = try Workout
                .filter(Column("endedAt") == nil)
                .filter(Column("deletedAt") == nil)
                .order(Column("startedAt").desc)
                .fetchAll(db)

            for var workout in unfinished {
                guard let details = try loadDetails(id: workout.id, in: db) else { continue }

                let setDates = details.exercises.flatMap(\.sets).map(\.createdAt)
                let lastActivity = setDates.max() ?? workout.startedAt

                if now.timeIntervalSince(lastActivity) <= staleAfter {
                    return details
                }

                if setDates.isEmpty {
                    workout.deletedAt = now
                } else {
                    // End at the last set, not now, so idle time doesn't inflate the duration.
                    workout.endedAt = lastActivity
                }
                workout.updatedAt = now
                try workout.save(db)
            }
            return nil
        }
    }

    public func fetchLastSets(for exerciseId: String) throws -> [SetEntry] {
        try database.read { db in
            let lastWorkoutExercise = try WorkoutExercise.filter(Column("exerciseId") == exerciseId)
                .filter(Column("deletedAt") == nil)
                .joining(required: WorkoutExercise.workout
                    .filter(Column("deletedAt") == nil)
                    .filter(Column("endedAt") != nil)
                    .order(Column("startedAt").desc))
                .fetchOne(db)

            guard let lastWorkoutExercise else {
                return []
            }

            return try SetEntry.filter(Column("workoutExerciseId") == lastWorkoutExercise.id)
                .filter(Column("deletedAt") == nil)
                .order(Column("position"))
                .fetchAll(db)
        }
    }

    /// Finished workouts, newest first, with duration and total volume.
    public func fetchRecentWorkouts() throws -> [WorkoutSummary] {
        try database.read { db in
            // N+1: two queries per workout. Replace with an aggregate before history grows.
            let workouts = try Workout
                .filter(Column("deletedAt") == nil)
                .filter(Column("endedAt") != nil)
                .order(Column("startedAt").desc)
                .fetchAll(db)

            return try workouts.map { workout in
                let workoutExerciseIds = try WorkoutExercise
                    .filter(Column("workoutId") == workout.id)
                    .fetchAll(db)
                    .map(\.id)

                let sets = try SetEntry
                    .filter(workoutExerciseIds.contains(Column("workoutExerciseId")))
                    .filter(Column("deletedAt") == nil)
                    .fetchAll(db)

                let totalVolume = WorkoutMath.totalVolume(of: sets.map { (reps: $0.reps, weight: $0.weight) })

                return WorkoutSummary(
                    id: workout.id,
                    startedAt: workout.startedAt,
                    duration: (workout.endedAt ?? workout.startedAt).timeIntervalSince(workout.startedAt),
                    totalVolume: totalVolume
                )
            }
        }
    }
}
