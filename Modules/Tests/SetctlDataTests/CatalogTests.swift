//
//  CatalogTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/27/26.
//

import Foundation
@testable import SetctlData
import Testing

@Test func catalogFileIsValid() throws {
    let entries = try ExerciseCatalog.load()
    #expect(Set(entries.map(\.id)).count == entries.count)
    #expect(Set(entries.map { $0.name.lowercased() }).count == entries.count)
    #expect(entries.allSatisfy { UUID(uuidString: $0.id) != nil })
    #expect(entries.allSatisfy { ExerciseCatalog.muscles.contains($0.muscle) })
}

@Test func originalExercisesKeepTheirIds() throws {
    let names = try Dictionary(uniqueKeysWithValues: ExerciseCatalog.load().map { ($0.id, $0.name) })
    #expect(names["00000000-0000-0000-0000-000000000001"] == "Barbell Bench Press")
    #expect(names["00000000-0000-0000-0000-000000000002"] == "Barbell Back Squat")
    #expect(names["00000000-0000-0000-0000-000000000006"] == "Pull-Up")
    #expect(names["00000000-0000-0000-0000-000000000008"] == "Dip")
}

@Test func syncingTheCatalogTwiceChangesNothing() throws {
    let database = try AppDatabase.empty()
    let expected = try ExerciseCatalog.load().count
    try database.write { db in try ExerciseCatalog.sync(into: db) }
    let exercises = try ExerciseRepository(database: database).fetchAllExercises()
    #expect(exercises.count == expected)
    #expect(exercises.first { $0.id == "00000000-0000-0000-0000-000000000002" }?.primaryMuscle == "quads")
}
