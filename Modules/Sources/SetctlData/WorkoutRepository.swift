//
//  WorkoutRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/22/26.
//

import Foundation
import GRDB
import SetctlCore

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

    public func fetchDetails(id: String) throws -> WorkoutDetails? {
        try database.read { db in
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
    }

    public func fetchLastSets(for exerciseId: String) throws -> [SetEntry] {
        try database.read { db in
            let lastWorkoutExercise = try WorkoutExercise.filter(Column("exerciseId") == exerciseId)
                .filter(Column("deletedAt") == nil)
                .joining(required: WorkoutExercise.workout
                    .filter(Column("deletedAt") == nil)
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

    public func fetchRecentWorkouts() throws -> [WorkoutSummary] {
        try database.read { db in
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
