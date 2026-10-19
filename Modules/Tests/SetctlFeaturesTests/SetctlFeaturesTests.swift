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

@Test func resumedSessionRestoresExercisesAndSets() throws {
    let (model, _) = try makeResumedSession()

    #expect(model.exercises.count == 1)
    #expect(model.exercises[0].exercise.name == "Bench Press")
    #expect(model.exercises[0].sets.map(\.weight) == [100, 105])
    #expect(model.exercises[0].previousSets.isEmpty)
    #expect(model.workout.endedAt == nil)
}

@Test func resumedSessionKeepsSaving() throws {
    let (model, database) = try makeResumedSession()

    model.addSet(to: model.exercises[0].id, reps: 5, weight: 110)

    let saved = try #require(try WorkoutRepository(database: database).fetchDetails(id: model.workout.id))
    #expect(saved.exercises[0].sets.map(\.position) == [0, 1, 2])
}

@Test func successfulSyncBecomesSyncedWithTheTime() {
    let now = Date(timeIntervalSince1970: 1_000_000)

    #expect(SyncStatus.from(.success(.synced), now: now) == .synced(now))
}

@Test func skippedSyncBecomesIdle() {
    #expect(SyncStatus.from(.success(.skipped)) == .idle)
}

@Test func refusedAccountBecomesWrongAccount() {
    #expect(SyncStatus.from(.failure(SyncError.deviceBelongsToAnotherAccount)) == .wrongAccount)
}

@Test func anyOtherErrorBecomesFailed() {
    struct Boom: Error {}

    #expect(SyncStatus.from(.failure(Boom())) == .failed)
}

@Test func syncStatusTextIsHiddenWhenSyncIsOff() {
    #expect(SyncStatus.off.displayText == nil)
}

@Test func syncStatusTextNamesEachState() {
    #expect(SyncStatus.idle.displayText == "SYNC: READY")
    #expect(SyncStatus.syncing.displayText == "SYNCING...")
    #expect(SyncStatus.failed.displayText == "SYNC FAILED. WILL RETRY.")
    #expect(SyncStatus.wrongAccount.displayText?.contains("ANOTHER ACCOUNT") == true)
    #expect(SyncStatus.synced(Date()).displayText?.hasPrefix("SYNCED: ") == true)
}

@Test func onlyProblemStatesAreWarnings() {
    #expect(SyncStatus.failed.isWarning)
    #expect(SyncStatus.wrongAccount.isWarning)
    #expect(!SyncStatus.idle.isWarning)
    #expect(!SyncStatus.syncing.isWarning)
    #expect(!SyncStatus.synced(Date()).isWarning)
}

@Test func syncNowIsOfferedOnlyWhenItCanHelp() {
    #expect(SyncStatus.idle.canSyncNow)
    #expect(SyncStatus.synced(Date()).canSyncNow)
    #expect(SyncStatus.failed.canSyncNow)
    #expect(!SyncStatus.syncing.canSyncNow)
    #expect(!SyncStatus.off.canSyncNow)
    #expect(!SyncStatus.wrongAccount.canSyncNow)
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

private func makeResumedSession() throws -> (model: ActiveSessionModel, database: AppDatabase) {
    let (original, database) = try makeSession()
    let sessionExerciseId = original.exercises[0].id
    original.addSet(to: sessionExerciseId, reps: 5, weight: 100)
    original.addSet(to: sessionExerciseId, reps: 5, weight: 105)

    let repository = WorkoutRepository(database: database)
    let details = try #require(try repository.fetchDetails(id: original.workout.id))
    let resumed = try ActiveSessionModel(
        resuming: details,
        workoutRepository: repository,
        exerciseRepository: ExerciseRepository(database: database)
    )
    return (resumed, database)
}
