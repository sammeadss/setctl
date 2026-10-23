//
//  ExportTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/23/26.
//

import Foundation
@testable import SetctlData
import Testing

@Test func fetchExportRowsFlattensSetsInPerformedOrder() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let exercise = try saveExercise(in: database)
    let older = Date(timeIntervalSince1970: 1_000_000)
    let newer = Date(timeIntervalSince1970: 2_000_000)

    // Saved newest-first so the query's ORDER BY, not insertion order, decides the result.
    try repository.save(makeDetails(exercise: exercise, date: newer, sets: [(8, 60)]))
    try repository.save(makeDetails(exercise: exercise, date: older, sets: [(5, 100), (5, 105)]))

    let rows = try repository.fetchExportRows()
    #expect(rows.map(\.workoutDate) == [older, older, newer])
    #expect(rows.map(\.setNumber) == [1, 2, 1])
    #expect(rows.map(\.weightKilograms) == [100, 105, 60])
    #expect(rows.first?.exercise == exercise.name)
}

@Test func fetchExportRowsSkipsSoftDeletedSetsAndWorkouts() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let exercise = try saveExercise(in: database)
    let date = Date(timeIntervalSince1970: 1_000_000)

    var withDeletedSet = makeDetails(exercise: exercise, date: date, sets: [(5, 100), (5, 105)])
    withDeletedSet.exercises[0].sets[1].deletedAt = date
    var deletedWorkout = makeDetails(exercise: exercise, date: date.addingTimeInterval(60), sets: [(3, 200)])
    deletedWorkout.workout.deletedAt = date

    try repository.save(withDeletedSet)
    try repository.save(deletedWorkout)

    let rows = try repository.fetchExportRows()
    #expect(rows.map(\.weightKilograms) == [100])
}
