//
//  SyncStoreTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
@testable import SetctlData
import Testing

private let userId = "7cd2758b-b159-47e0-b623-fd9d89440662"

private func remoteWorkout(
    id: String = UUID().uuidString,
    note: String?,
    updatedAt: Date,
    deletedAt: Date? = nil
) -> RemoteWorkout {
    let start = Date(timeIntervalSince1970: 1_000_000)
    var row = RemoteWorkout(
        Workout(
            id: id, startedAt: start, note: note,
            createdAt: start, updatedAt: updatedAt, deletedAt: deletedAt
        ),
        userId: userId
    )
    row.serverUpdatedAt = updatedAt
    return row
}

private func noteAfterApplying(remoteUpdatedAt seconds: TimeInterval) throws -> String? {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let id = UUID().uuidString
    let start = Date(timeIntervalSince1970: 1_000_000)
    try repository.save(Workout(
        id: id, startedAt: start, note: "local",
        createdAt: start, updatedAt: Date(timeIntervalSince1970: 2_000_000)
    ))

    try SyncStore(database: database).applyRemote([
        remoteWorkout(id: id, note: "remote", updatedAt: Date(timeIntervalSince1970: seconds)),
    ])

    return try repository.fetchWorkout(id: id)?.note
}

@Test func applyRemoteInsertsRowsMissingLocally() throws {
    let database = try AppDatabase.empty()
    let row = remoteWorkout(note: "from server", updatedAt: Date(timeIntervalSince1970: 2_000_000))

    try SyncStore(database: database).applyRemote([row])

    let stored = try WorkoutRepository(database: database).fetchWorkout(id: row.local.id)
    #expect(stored?.note == "from server")
}

@Test func applyRemoteIgnoresOlderRows() throws {
    #expect(try noteAfterApplying(remoteUpdatedAt: 1_000_000) == "local")
}

@Test func applyRemoteKeepsLocalRowOnEqualTimestamps() throws {
    #expect(try noteAfterApplying(remoteUpdatedAt: 2_000_000) == "local")
}

@Test func applyRemoteReplacesOlderLocalRows() throws {
    #expect(try noteAfterApplying(remoteUpdatedAt: 3_000_000) == "remote")
}

@Test func applyRemoteStoresTombstones() throws {
    let database = try AppDatabase.empty()
    let stamp = Date(timeIntervalSince1970: 3_000_000)
    let row = remoteWorkout(note: nil, updatedAt: stamp, deletedAt: stamp)

    try SyncStore(database: database).applyRemote([row])

    let stored = try WorkoutRepository(database: database).fetchWorkout(id: row.local.id)
    #expect(stored?.deletedAt != nil)
}

@Test func applyRemoteHandlesParentsBeforeChildren() throws {
    let database = try AppDatabase.empty()
    let store = SyncStore(database: database)
    let date = Date(timeIntervalSince1970: 1_000_000)
    let workout = Workout(startedAt: date, createdAt: date, updatedAt: date)
    let workoutExercise = WorkoutExercise(
        workoutId: workout.id, exerciseId: "00000000-0000-0000-0000-000000000001",
        position: 0, updatedAt: date
    )
    let set = SetEntry(
        workoutExerciseId: workoutExercise.id, position: 0, reps: 5, weight: 100,
        weightUnit: "kg", isWarmup: false, isCompleted: true, createdAt: date, updatedAt: date
    )

    try store.applyRemote([RemoteWorkout(workout, userId: userId)])
    try store.applyRemote([RemoteWorkoutExercise(workoutExercise, userId: userId)])
    try store.applyRemote([RemoteSetEntry(set, userId: userId)])

    let details = try #require(try WorkoutRepository(database: database).fetchDetails(id: workout.id))
    #expect(details.exercises.count == 1)
    #expect(details.exercises[0].sets.count == 1)
}

@Test func changedRowsStartAtTheCursorInclusively() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    _ = try saveWorkout(repository, updatedAt: 1_000_000)
    let second = try saveWorkout(repository, updatedAt: 2_000_000)
    let third = try saveWorkout(repository, updatedAt: 3_000_000)

    let batch = try SyncStore(database: database).changedRows(
        RemoteWorkout.self, since: Date(timeIntervalSince1970: 2_000_000), limit: 100, userId: userId
    )

    #expect(batch.rows.map(\.local.id) == [second.id, third.id])
    #expect(batch.highWaterMark == Date(timeIntervalSince1970: 3_000_000))
}

@Test func changedRowsWithoutACursorReturnEverythingOldestFirst() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let newer = try saveWorkout(repository, updatedAt: 3_000_000)
    let older = try saveWorkout(repository, updatedAt: 1_000_000)

    let batch = try SyncStore(database: database).changedRows(
        RemoteWorkout.self, since: nil, limit: 100, userId: userId
    )

    #expect(batch.rows.map(\.local.id) == [older.id, newer.id])
}

@Test func changedRowsNeverSplitARunOfEqualTimestamps() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let first = try saveWorkout(repository, updatedAt: 2_000_000)
    let second = try saveWorkout(repository, updatedAt: 2_000_000)
    let third = try saveWorkout(repository, updatedAt: 2_000_000)
    _ = try saveWorkout(repository, updatedAt: 3_000_000)

    let batch = try SyncStore(database: database).changedRows(
        RemoteWorkout.self, since: nil, limit: 2, userId: userId
    )

    #expect(Set(batch.rows.map(\.local.id)) == Set([first.id, second.id, third.id]))
    #expect(batch.highWaterMark == Date(timeIntervalSince1970: 2_000_000))
}

@Test func changedRowsIncludeTombstonesAndTheOwningUser() throws {
    let database = try AppDatabase.empty()
    let repository = WorkoutRepository(database: database)
    let stamp = Date(timeIntervalSince1970: 2_000_000)
    _ = try saveWorkout(repository, updatedAt: 2_000_000, deletedAt: stamp)

    let batch = try SyncStore(database: database).changedRows(
        RemoteWorkout.self, since: nil, limit: 100, userId: userId.uppercased()
    )

    let row = try #require(batch.rows.first)
    #expect(row.deletedAt == stamp)
    #expect(row.userId == userId.lowercased())
}

private func saveWorkout(
    _ repository: WorkoutRepository,
    updatedAt seconds: TimeInterval,
    deletedAt: Date? = nil
) throws -> Workout {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let workout = Workout(
        startedAt: start, createdAt: start,
        updatedAt: Date(timeIntervalSince1970: seconds), deletedAt: deletedAt
    )
    try repository.save(workout)
    return workout
}
