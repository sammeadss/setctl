//
//  SyncEngineTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
@testable import SetctlData
import Testing

private let userId = "7CD2758B-B159-47E0-B623-FD9D89440662"

private enum FakeRemoteError: Error {
    case offline
}

private final class FakeRemote: SyncRemote, @unchecked Sendable {
    private let lock = NSLock()
    private var tables: [String: [Any]] = [:]
    private var clock = 0
    private var offline = false
    private var pushLog: [String] = []

    var pushedTables: [String] {
        lock.withLock { pushLog }
    }

    func setOffline(_ value: Bool) {
        lock.withLock { offline = value }
    }

    func seed(_ rows: [some SyncRow]) {
        lock.withLock { upsert(rows) }
    }

    func stored<Row: SyncRow>(_: Row.Type) -> [Row] {
        lock.withLock { (tables[Row.remoteTable] as? [Row]) ?? [] }
    }

    func push<Row: SyncRow>(_ rows: [Row]) async throws {
        try lock.withLock {
            if offline {
                throw FakeRemoteError.offline
            }
            pushLog.append(Row.remoteTable)
            upsert(rows)
        }
    }

    func pull<Row: SyncRow>(_: Row.Type, since: Date, limit: Int) async throws -> [Row] {
        lock.withLock {
            let rows = (tables[Row.remoteTable] as? [Row]) ?? []
            let newer = rows.filter { ($0.serverUpdatedAt ?? .distantPast) >= since }
            let ordered = newer.sorted {
                ($0.serverUpdatedAt ?? .distantPast) < ($1.serverUpdatedAt ?? .distantPast)
            }
            return Array(ordered.prefix(limit))
        }
    }

    private func upsert<Row: SyncRow>(_ rows: [Row]) {
        var existing = (tables[Row.remoteTable] as? [Row]) ?? []
        for var row in rows {
            let index = existing.firstIndex { $0.local.id == row.local.id }
            if let index, row.local.updatedAt <= existing[index].local.updatedAt {
                continue
            }
            clock += 1
            row.serverUpdatedAt = Date(timeIntervalSince1970: 10_000_000 + Double(clock))
            if let index {
                existing[index] = row
            } else {
                existing.append(row)
            }
        }
        tables[Row.remoteTable] = existing
    }
}

private func makeEngine(_ remote: FakeRemote, database: AppDatabase, pageSize: Int = 500) -> SyncEngine {
    SyncEngine(remote: remote, database: database, pageSize: pageSize)
}

private func saveWorkout(
    _ database: AppDatabase,
    id: String = UUID().uuidString,
    note: String?,
    updatedAt seconds: TimeInterval
) throws -> Workout {
    let start = Date(timeIntervalSince1970: 1_000_000)
    let workout = Workout(
        id: id, startedAt: start, note: note,
        createdAt: start, updatedAt: Date(timeIntervalSince1970: seconds)
    )
    try WorkoutRepository(database: database).save(workout)
    return workout
}

@Test func syncPushesLocalRowsToAnEmptyServer() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
    let workout = try saveWorkout(database, note: "local", updatedAt: 2_000_000)

    try await makeEngine(remote, database: database).sync(userId: userId)

    let pushed = try #require(remote.stored(RemoteWorkout.self).first)
    #expect(pushed.id == workout.id.lowercased())
    #expect(pushed.note == "local")
    let cursor = try SyncStateRepository(database: database).cursor(userId: userId, table: .workout)
    #expect(cursor.pushedUpTo == Date(timeIntervalSince1970: 2_000_000))
}

@Test func syncPullsServerRowsIntoAnEmptyDevice() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
    let start = Date(timeIntervalSince1970: 1_000_000)
    let serverWorkout = Workout(startedAt: start, note: "from server", createdAt: start, updatedAt: start)
    remote.seed([RemoteWorkout(serverWorkout, userId: userId)])

    try await makeEngine(remote, database: database).sync(userId: userId)

    let local = try WorkoutRepository(database: database).fetchWorkout(id: serverWorkout.id)
    #expect(local?.note == "from server")
    let cursor = try SyncStateRepository(database: database).cursor(userId: userId, table: .workout)
    #expect(cursor.pulledUpTo != nil)
}

@Test func syncPullsEveryPageUntilTheServerRunsOut() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
    let start = Date(timeIntervalSince1970: 1_000_000)
    for index in 1 ... 5 {
        let workout = Workout(startedAt: start, note: "w\(index)", createdAt: start, updatedAt: start)
        remote.seed([RemoteWorkout(workout, userId: userId)])
    }

    try await makeEngine(remote, database: database, pageSize: 2).sync(userId: userId)

    let count = try database.read { db in try Workout.fetchCount(db) }
    #expect(count == 5)
}

@Test func newerLocalEditWinsOverTheServer() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
    let start = Date(timeIntervalSince1970: 1_000_000)
    let id = UUID().uuidString
    let serverCopy = Workout(
        id: id, startedAt: start, note: "server", createdAt: start,
        updatedAt: Date(timeIntervalSince1970: 2_000_000)
    )
    remote.seed([RemoteWorkout(serverCopy, userId: userId)])
    _ = try saveWorkout(database, id: id, note: "local", updatedAt: 3_000_000)

    try await makeEngine(remote, database: database).sync(userId: userId)

    #expect(remote.stored(RemoteWorkout.self).first?.note == "local")
    #expect(try WorkoutRepository(database: database).fetchWorkout(id: id)?.note == "local")
}

@Test func newerServerEditWinsOverTheLocalCopy() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
    let start = Date(timeIntervalSince1970: 1_000_000)
    let id = UUID().uuidString
    let serverCopy = Workout(
        id: id, startedAt: start, note: "server", createdAt: start,
        updatedAt: Date(timeIntervalSince1970: 3_000_000)
    )
    remote.seed([RemoteWorkout(serverCopy, userId: userId)])
    _ = try saveWorkout(database, id: id, note: "local", updatedAt: 2_000_000)

    try await makeEngine(remote, database: database).sync(userId: userId)

    #expect(try WorkoutRepository(database: database).fetchWorkout(id: id)?.note == "server")
    #expect(remote.stored(RemoteWorkout.self).first?.note == "server")
}

@Test func failedPushLosesNothing() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
    _ = try saveWorkout(database, note: "keep me", updatedAt: 2_000_000)
    let engine = makeEngine(remote, database: database)
    remote.setOffline(true)

    await #expect(throws: FakeRemoteError.self) {
        try await engine.sync(userId: userId)
    }
    let afterFailure = try SyncStateRepository(database: database).cursor(userId: userId, table: .workout)
    #expect(afterFailure.pushedUpTo == nil)

    remote.setOffline(false)
    try await engine.sync(userId: userId)

    #expect(remote.stored(RemoteWorkout.self).first?.note == "keep me")
}

@Test func pushSendsParentsBeforeChildren() async throws {
    let database = try AppDatabase.empty()
    let remote = FakeRemote()
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
    try WorkoutRepository(database: database).save(WorkoutDetails(
        workout: workout,
        exercises: [WorkoutExerciseWithSets(workoutExercise: workoutExercise, sets: [set])]
    ))

    try await makeEngine(remote, database: database).sync(userId: userId)

    #expect(remote.pushedTables == ["workouts", "workout_exercises", "set_entries"])
}
