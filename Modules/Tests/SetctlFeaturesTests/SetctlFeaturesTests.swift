import Foundation
@testable import SetctlData
@testable import SetctlFeatures
import Testing

@Test func deleteSetRenumbersRemainingSets() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let model = ActiveSessionModel(workoutRepository: repository)

    let exercise = Exercise(
        name: "Bench Press", primaryMuscle: "chest",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: Date(), deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }
    model.addExercise(exercise)
    model.addSet(to: model.exercises[0].id, reps: 5, weight: 100)
    model.addSet(to: model.exercises[0].id, reps: 5, weight: 105)
    model.addSet(to: model.exercises[0].id, reps: 5, weight: 110)

    let sessionExerciseId = model.exercises[0].id
    let middleSetId = model.exercises[0].sets[1].id

    model.deleteSet(from: sessionExerciseId, setId: middleSetId)

    let remaining = model.exercises[0].sets
    #expect(remaining.count == 2)
    #expect(!remaining.contains { $0.id == middleSetId })
    #expect(remaining.map(\.position) == [0, 1])
}

@Test func sessionIsSavedAfterEachChange() throws {
    let (model, database) = try makeSession()
    model.addSet(to: model.exercises[0].id, reps: 5, weight: 100)

    let saved = try #require(
        try WorkoutRepository(database: database).fetchDetails(id: model.workout.id)
    )

    #expect(saved.workout.endedAt == nil)
    #expect(saved.exercises.count == 1)
    #expect(saved.exercises[0].sets.count == 1)
}

@Test func deletedSetIsKeptAsTombstone() throws {
    let (model, database) = try makeSession()
    let sessionExerciseId = model.exercises[0].id
    model.addSet(to: sessionExerciseId, reps: 5, weight: 100)
    model.addSet(to: sessionExerciseId, reps: 5, weight: 105)
    let deletedId = model.exercises[0].sets[0].id

    model.deleteSet(from: sessionExerciseId, setId: deletedId)

    let stored = try database.read { db in try SetEntry.fetchAll(db) }
    #expect(stored.count == 2)
    #expect(stored.first { $0.id == deletedId }?.deletedAt != nil)

    let visible = try WorkoutRepository(database: database).fetchDetails(id: model.workout.id)
    #expect(visible?.exercises[0].sets.count == 1)
}

@Test func onlyShiftedSetsAreRestamped() throws {
    let (model, _) = try makeSession()
    let sessionExerciseId = model.exercises[0].id
    model.addSet(to: sessionExerciseId, reps: 5, weight: 100)
    model.addSet(to: sessionExerciseId, reps: 5, weight: 105)
    model.addSet(to: sessionExerciseId, reps: 5, weight: 110)
    let stamps = model.exercises[0].sets.map(\.updatedAt)

    model.deleteSet(from: sessionExerciseId, setId: model.exercises[0].sets[2].id)
    #expect(model.exercises[0].sets.map(\.updatedAt) == Array(stamps[0 ... 1]))

    model.deleteSet(from: sessionExerciseId, setId: model.exercises[0].sets[0].id)
    #expect(model.exercises[0].sets[0].updatedAt > stamps[1])
}

@Test func failedSaveSetsSaveFailed() throws {
    let database = try AppDatabase.empty()
    let model = ActiveSessionModel(workoutRepository: WorkoutRepository(database: database))
    let unsaved = Exercise(
        name: "Ghost", primaryMuscle: "chest",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: Date(), deletedAt: nil
    )

    model.addExercise(unsaved)

    #expect(model.saveFailed)
}

private func makeSession() throws -> (model: ActiveSessionModel, database: AppDatabase) {
    let database = try AppDatabase.empty()
    let model = ActiveSessionModel(workoutRepository: WorkoutRepository(database: database))

    let exercise = Exercise(
        name: "Bench Press", primaryMuscle: "chest",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: Date(), deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }
    model.addExercise(exercise)
    return (model, database)
}
