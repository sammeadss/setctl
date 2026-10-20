//
//  WorkoutDetails.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/22/26.
//

import Foundation

/// A workout with its exercises and sets, loaded and saved together.
public struct WorkoutDetails: Equatable {
    public var workout: Workout
    public var exercises: [WorkoutExerciseWithSets]

    public init(
        workout: Workout,
        exercises: [WorkoutExerciseWithSets]
    ) {
        self.workout = workout
        self.exercises = exercises
    }
}

/// A workout exercise with its sets, ordered by position.
public struct WorkoutExerciseWithSets: Equatable {
    public var workoutExercise: WorkoutExercise
    public var sets: [SetEntry]

    public init(
        workoutExercise: WorkoutExercise,
        sets: [SetEntry]
    ) {
        self.workoutExercise = workoutExercise
        self.sets = sets
    }
}
