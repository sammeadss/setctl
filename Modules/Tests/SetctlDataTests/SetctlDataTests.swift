import Foundation
@testable import SetctlData
import Testing

@Test func migrationRuns() throws {
    _ = try AppDatabase.empty()
}

@Test func savesAndFetchesWorkout() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)

    let date = Date(timeIntervalSince1970: 1_000_000)
    let workout = Workout(
        startedAt: date,
        endedAt: nil,
        note: "leg day",
        createdAt: date,
        updatedAt: date,
        deletedAt: nil
    )
    try repository.save(workout)

    let fetched = try repository.fetchWorkout(id: workout.id)
    #expect(fetched == workout)
}

@Test func savesAndFetchesWorkoutDetails() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let date = Date(timeIntervalSince1970: 1_000_000)

    let exercise = Exercise(
        name: "Squat",
        primaryMuscle: "legs",
        isBodyweight: true,
        isCustom: false,
        ownerId: nil,
        updatedAt: date,
        deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }

    let workout = Workout(
        startedAt: date, endedAt: nil, note: "leg day",
        createdAt: date, updatedAt: date, deletedAt: nil
    )
    let workoutExercise = WorkoutExercise(
        workoutId: workout.id, exerciseId: exercise.id,
        position: 0, updatedAt: date, deletedAt: nil
    )
    let set1 = SetEntry(
        workoutExerciseId: workoutExercise.id, position: 0,
        reps: 5, weight: 100, weightUnit: "kg", rpe: nil,
        isWarmup: false, isCompleted: true,
        createdAt: date, updatedAt: date, deletedAt: nil
    )
    let set2 = SetEntry(
        workoutExerciseId: workoutExercise.id, position: 1,
        reps: 5, weight: 105, weightUnit: "kg", rpe: 8,
        isWarmup: false, isCompleted: true,
        createdAt: date, updatedAt: date, deletedAt: nil
    )

    let details = WorkoutDetails(
        workout: workout,
        exercises: [
            WorkoutExerciseWithSets(workoutExercise: workoutExercise, sets: [set1, set2]),
        ]
    )

    try repository.save(details)
    let fetched = try repository.fetchDetails(id: workout.id)

    #expect(fetched == details)
}

@Test func seedsExerciseCatalog() throws {
    let database = try AppDatabase.empty()

    try database.read { db in
        let count = try Exercise.fetchCount(db)
        #expect(count == 8)

        let pullUp = try Exercise.fetchOne(db, id: "00000000-0000-0000-0000-000000000006")
        #expect(pullUp?.name == "Pull-Up")
        #expect(pullUp?.isBodyweight == true)
    }
}

@Test func fetchesLastSetsFromMostRecentWorkout() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)

    let olderDate = Date(timeIntervalSince1970: 1_000_000)
    let newerDate = Date(timeIntervalSince1970: 2_000_000)

    let exercise = Exercise(
        name: "Bench Press", primaryMuscle: "chest",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: olderDate, deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }

    let newerDetails = makeDetails(
        exercise: exercise, date: newerDate, endedAt: newerDate.addingTimeInterval(1800), sets: [(8, 60), (8, 62.5)]
    )
    let olderDetails = makeDetails(
        exercise: exercise, date: olderDate, endedAt: olderDate.addingTimeInterval(1800), sets: [(5, 100)]
    )

    // Saved newest-first so the query's ORDER BY, not insertion order, must pick the winner.
    try repository.save(newerDetails)
    try repository.save(olderDetails)

    let lastSets = try repository.fetchLastSets(for: exercise.id)
    #expect(lastSets == newerDetails.exercises[0].sets)
}

@Test func fetchLastSetsIgnoresUnfinishedWorkouts() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)

    let olderDate = Date(timeIntervalSince1970: 1_000_000)
    let newerDate = Date(timeIntervalSince1970: 2_000_000)

    let exercise = Exercise(
        name: "Bench Press", primaryMuscle: "chest",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: olderDate, deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }

    let finished = makeDetails(
        exercise: exercise, date: olderDate, endedAt: olderDate.addingTimeInterval(1800), sets: [(5, 100)]
    )
    let inProgress = makeDetails(exercise: exercise, date: newerDate, sets: [(8, 60)])
    try repository.save(finished)
    try repository.save(inProgress)

    let lastSets = try repository.fetchLastSets(for: exercise.id)
    #expect(lastSets == finished.exercises[0].sets)
}

@Test func fetchRecentWorkoutsReturnsEndedWorkoutsNewestFirst() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)

    let exercise = Exercise(
        name: "Deadlift", primaryMuscle: "back",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: Date(timeIntervalSince1970: 1_000_000), deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }

    let olderStart = Date(timeIntervalSince1970: 1_000_000)
    let olderEnd = Date(timeIntervalSince1970: 1_000_600)
    let newerStart = Date(timeIntervalSince1970: 2_000_000)
    let newerEnd = Date(timeIntervalSince1970: 2_001_200)

    let olderDetails = makeDetails(exercise: exercise, date: olderStart, endedAt: olderEnd, sets: [(5, 100)])
    let newerDetails = makeDetails(exercise: exercise, date: newerStart, endedAt: newerEnd, sets: [(8, 60), (8, 62.5)])

    try repository.save(olderDetails)
    try repository.save(newerDetails)

    let summaries = try repository.fetchRecentWorkouts()

    #expect(summaries.map(\.id) == [newerDetails.workout.id, olderDetails.workout.id])
    #expect(summaries[0].duration == 1200)
    #expect(summaries[0].totalVolume == 8 * 60.0 + 8 * 62.5)
}

@Test func fetchRecentWorkoutsExcludesUnendedWorkouts() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)

    let exercise = Exercise(
        name: "Row", primaryMuscle: "back",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: Date(timeIntervalSince1970: 1_000_000), deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }

    let inProgress = makeDetails(exercise: exercise, date: Date(timeIntervalSince1970: 1_000_000), sets: [(5, 50)])
    try repository.save(inProgress)

    let summaries = try repository.fetchRecentWorkouts()
    #expect(summaries.isEmpty)
}

@Test func fetchLastSetsReturnsEmptyWithoutHistory() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)

    let lastSets = try repository.fetchLastSets(for: "missing")
    #expect(lastSets.isEmpty)
}

@Test func fetchDetailsExcludesDeletedSets() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let date = Date(timeIntervalSince1970: 1_000_000)

    let exercise = Exercise(
        name: "Row", primaryMuscle: "back",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: date, deletedAt: nil
    )
    try database.write { db in try exercise.save(db) }

    var details = makeDetails(exercise: exercise, date: date, sets: [(5, 50), (5, 55)])
    details.exercises[0].sets[0].deletedAt = date
    try repository.save(details)

    let fetched = try repository.fetchDetails(id: details.workout.id)

    #expect(fetched?.exercises[0].sets.map(\.weight) == [55])
}

@Test func resolveUnfinishedReturnsRecentWorkout() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let exercise = try saveExercise(in: database)
    let date = Date(timeIntervalSince1970: 1_000_000)
    let details = makeDetails(exercise: exercise, date: date, sets: [(5, 50)])
    try repository.save(details)

    let resolved = try repository.resolveUnfinishedWorkout(now: date.addingTimeInterval(3600))

    #expect(resolved == details)
}

@Test func resolveUnfinishedFinishesStaleWorkoutAtItsLastSet() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let exercise = try saveExercise(in: database)
    let date = Date(timeIntervalSince1970: 1_000_000)
    var details = makeDetails(exercise: exercise, date: date, sets: [(5, 50), (5, 55)])
    let lastSetAt = date.addingTimeInterval(600)
    details.exercises[0].sets[1].createdAt = lastSetAt
    try repository.save(details)

    let resolved = try repository.resolveUnfinishedWorkout(now: date.addingTimeInterval(13 * 3600))

    #expect(resolved == nil)
    let stored = try #require(try repository.fetchWorkout(id: details.workout.id))
    #expect(stored.endedAt == lastSetAt)
    #expect(try repository.fetchRecentWorkouts().map(\.id) == [details.workout.id])
}

@Test func resolveUnfinishedDiscardsStaleWorkoutWithoutSets() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let exercise = try saveExercise(in: database)
    let date = Date(timeIntervalSince1970: 1_000_000)
    let details = makeDetails(exercise: exercise, date: date, sets: [])
    try repository.save(details)

    let resolved = try repository.resolveUnfinishedWorkout(now: date.addingTimeInterval(13 * 3600))

    #expect(resolved == nil)
    let stored = try #require(try repository.fetchWorkout(id: details.workout.id))
    #expect(stored.deletedAt != nil)
}

@Test func resolveUnfinishedIgnoresFinishedWorkouts() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let exercise = try saveExercise(in: database)
    let date = Date(timeIntervalSince1970: 1_000_000)
    let details = makeDetails(exercise: exercise, date: date, endedAt: date.addingTimeInterval(1800), sets: [(5, 50)])
    try repository.save(details)

    #expect(try repository.resolveUnfinishedWorkout(now: date.addingTimeInterval(3600)) == nil)
}

@Test func syncCursorStartsEmpty() throws {
    let repository = try SyncStateRepository(database: AppDatabase.empty())

    let cursor = try repository.cursor(userId: "user-a", table: .workout)

    #expect(cursor == SyncCursor(pushedUpTo: nil, pulledUpTo: nil))
}

@Test func savingOneCursorKeepsTheOther() throws {
    let repository = try SyncStateRepository(database: AppDatabase.empty())
    let pushed = Date(timeIntervalSince1970: 1_000_000)
    let pulled = Date(timeIntervalSince1970: 2_000_000)

    try repository.savePushedUpTo(pushed, userId: "user-a", table: .workout)
    try repository.savePulledUpTo(pulled, userId: "user-a", table: .workout)

    let cursor = try repository.cursor(userId: "user-a", table: .workout)
    #expect(cursor == SyncCursor(pushedUpTo: pushed, pulledUpTo: pulled))
}

@Test func syncCursorsAreScopedPerUserAndTable() throws {
    let repository = try SyncStateRepository(database: AppDatabase.empty())
    let date = Date(timeIntervalSince1970: 1_000_000)

    try repository.savePushedUpTo(date, userId: "user-a", table: .workout)

    #expect(try repository.cursor(userId: "user-b", table: .workout).pushedUpTo == nil)
    #expect(try repository.cursor(userId: "user-a", table: .setEntry).pushedUpTo == nil)
    #expect(try repository.cursor(userId: "user-a", table: .workout).pushedUpTo == date)
}

@Test func remoteRowsRoundTripThroughLocalModels() {
    let details = sampleDetails()
    let userId = UUID().uuidString

    let workout = RemoteWorkout(details.workout, userId: userId)
    let workoutExercise = RemoteWorkoutExercise(details.exercises[0].workoutExercise, userId: userId)
    let set = RemoteSetEntry(details.exercises[0].sets[0], userId: userId)

    #expect(workout.id == details.workout.id.lowercased())
    #expect(workout.userId == userId.lowercased())
    #expect(workout.local == details.workout)
    #expect(workoutExercise.local == details.exercises[0].workoutExercise)
    #expect(set.local == details.exercises[0].sets[0])
}

@Test func remoteRowsEncodeMissingValuesAsExplicitNulls() throws {
    let details = sampleDetails()
    let userId = UUID().uuidString

    let workoutData = try JSONEncoder().encode(RemoteWorkout(details.workout, userId: userId))
    let setData = try JSONEncoder().encode(RemoteSetEntry(details.exercises[0].sets[0], userId: userId))
    let workoutJSON = try #require(JSONSerialization.jsonObject(with: workoutData) as? [String: Any])
    let setJSON = try #require(JSONSerialization.jsonObject(with: setData) as? [String: Any])

    #expect(workoutJSON["ended_at"] is NSNull)
    #expect(workoutJSON["note"] is NSNull)
    #expect(workoutJSON["deleted_at"] is NSNull)
    #expect(workoutJSON["server_updated_at"] == nil)
    #expect(setJSON["rpe"] is NSNull)
}

private func sampleDetails() -> WorkoutDetails {
    let date = Date(timeIntervalSince1970: 1_000_000)
    let exercise = Exercise(
        name: "Row", primaryMuscle: "back",
        isBodyweight: false, isCustom: false, ownerId: nil,
        updatedAt: date, deletedAt: nil
    )
    return makeDetails(exercise: exercise, date: date, sets: [(5, 100)])
}
