//
//  TestSupport.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/23/26.
//

import Foundation
@testable import SetctlData

func makeDetails(
    exercise: Exercise,
    date: Date,
    endedAt: Date? = nil,
    sets: [(reps: Int, weight: Double)]
) -> WorkoutDetails {
    let workout = Workout(
        startedAt: date, endedAt: endedAt, note: nil,
        createdAt: date, updatedAt: date, deletedAt: nil
    )
    let workoutExercise = WorkoutExercise(
        workoutId: workout.id, exerciseId: exercise.id,
        position: 0, updatedAt: date, deletedAt: nil
    )
    let setEntries = sets.enumerated().map { index, set in
        SetEntry(
            workoutExerciseId: workoutExercise.id, position: index,
            reps: set.reps, weight: set.weight, weightUnit: "kg", rpe: nil,
            isWarmup: false, isCompleted: true,
            createdAt: date, updatedAt: date, deletedAt: nil
        )
    }
    return WorkoutDetails(
        workout: workout,
        exercises: [WorkoutExerciseWithSets(workoutExercise: workoutExercise, sets: setEntries)]
    )
}

func saveExercise(in database: AppDatabase) throws -> Exercise {
    let exercise = Exercise(
        name: "Row", primaryMuscle: "back",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: Date(timeIntervalSince1970: 1_000_000), deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }
    return exercise
}
