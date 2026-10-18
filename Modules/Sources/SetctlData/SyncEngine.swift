//
//  SyncEngine.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation

public enum SyncOutcome: Sendable {
    case synced
    case skipped
}

public enum SyncError: Error {
    case deviceBelongsToAnotherAccount
}

struct RetryPolicy: Sendable {
    var maxAttempts = 4
    var baseDelay: TimeInterval = 2
    var maxDelay: TimeInterval = 30

    func delay(afterAttempt attempt: Int) -> TimeInterval {
        min(baseDelay * pow(2, Double(attempt - 1)), maxDelay)
    }
}

actor SyncEngine {
    typealias Sleep = @Sendable (TimeInterval) async throws -> Void

    private let remote: any SyncRemote
    private let store: SyncStore
    private let cursors: SyncStateRepository
    private let pageSize: Int
    private let pullOverlap: TimeInterval
    private let retry: RetryPolicy
    private let sleep: Sleep
    private var inFlight: (userId: String, task: Task<Void, Error>)?

    init(
        remote: any SyncRemote,
        database: AppDatabase,
        pageSize: Int = 500,
        pullOverlap: TimeInterval = 5,
        retry: RetryPolicy = RetryPolicy(),
        sleep: @escaping Sleep = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.remote = remote
        store = SyncStore(database: database)
        cursors = SyncStateRepository(database: database)
        self.pageSize = pageSize
        self.pullOverlap = pullOverlap
        self.retry = retry
        self.sleep = sleep
    }

    @discardableResult
    func sync(userId: String) async throws -> SyncOutcome {
        if let running = inFlight {
            guard running.userId == userId else { return .skipped }
            try await running.task.value
            return .synced
        }

        guard try cursors.claimOwner(userId) else {
            throw SyncError.deviceBelongsToAnotherAccount
        }

        let task = Task { try await self.syncWithRetry(userId: userId) }
        inFlight = (userId, task)
        defer { inFlight = nil }
        try await task.value
        return .synced
    }

    private func syncWithRetry(userId: String) async throws {
        var attempt = 1
        while true {
            do {
                try await pullAll(userId: userId)
                try await pushAll(userId: userId)
                return
            } catch {
                if error is CancellationError || attempt >= retry.maxAttempts {
                    throw error
                }
                try await sleep(retry.delay(afterAttempt: attempt))
                attempt += 1
            }
        }
    }

    private func pullAll(userId: String) async throws {
        for table in SyncTable.allCases {
            switch table {
            case .workout:
                try await pull(RemoteWorkout.self, table: table, userId: userId)
            case .workoutExercise:
                try await pull(RemoteWorkoutExercise.self, table: table, userId: userId)
            case .setEntry:
                try await pull(RemoteSetEntry.self, table: table, userId: userId)
            }
        }
    }

    private func pushAll(userId: String) async throws {
        for table in SyncTable.allCases {
            switch table {
            case .workout:
                try await push(RemoteWorkout.self, table: table, userId: userId)
            case .workoutExercise:
                try await push(RemoteWorkoutExercise.self, table: table, userId: userId)
            case .setEntry:
                try await push(RemoteSetEntry.self, table: table, userId: userId)
            }
        }
    }

    private func pull(_ type: (some SyncRow).Type, table: SyncTable, userId: String) async throws {
        var cursor = try cursors.cursor(userId: userId, table: table).pulledUpTo
        var since = cursor.map { $0.addingTimeInterval(-pullOverlap) } ?? Date(timeIntervalSince1970: 0)

        while true {
            let page = try await remote.pull(type, since: since, limit: pageSize)
            try store.applyRemote(page)

            guard let newest = page.compactMap(\.serverUpdatedAt).max() else { return }
            if newest > (cursor ?? .distantPast) {
                try cursors.savePulledUpTo(newest, userId: userId, table: table)
                cursor = newest
            }

            guard page.count >= pageSize, newest > since else { return }
            since = newest
        }
    }

    private func push(_ type: (some SyncRow).Type, table: SyncTable, userId: String) async throws {
        var cursor = try cursors.cursor(userId: userId, table: table).pushedUpTo

        while true {
            let batch = try store.changedRows(type, since: cursor, limit: pageSize, userId: userId)
            guard let mark = batch.highWaterMark else { return }

            try await remote.push(batch.rows)
            try cursors.savePushedUpTo(mark, userId: userId, table: table)

            guard batch.rows.count >= pageSize, mark != cursor else { return }
            cursor = mark
        }
    }
}
