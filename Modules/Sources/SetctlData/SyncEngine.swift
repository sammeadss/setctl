//
//  SyncEngine.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation

public enum SyncOutcome: Sendable {
    case synced
    /// A sync for a different account was already running.
    case skipped
}

/// Thrown, and never retried, when the device was claimed by another account.
public enum SyncError: Error {
    case deviceBelongsToAnotherAccount
}

/// Exponential backoff: `baseDelay` doubles on each attempt, capped at `maxDelay`.
struct RetryPolicy: Sendable {
    var maxAttempts = 4
    var baseDelay: TimeInterval = 2
    var maxDelay: TimeInterval = 30

    func delay(afterAttempt attempt: Int) -> TimeInterval {
        min(baseDelay * pow(2, Double(attempt - 1)), maxDelay)
    }
}

/// Runs one sync at a time, pulling then pushing every table.
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
        // Single-flight: a repeat call for the same account joins the running sync.
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
        // Re-read a few seconds before the cursor: a row can commit after a later-stamped one, and re-applying a row is
        // harmless.
        var since = cursor.map { $0.addingTimeInterval(-pullOverlap) } ?? Date(timeIntervalSince1970: 0)

        while true {
            let page = try await remote.pull(type, since: since, limit: pageSize)
            try store.applyRemote(page)

            guard let newest = page.compactMap(\.serverUpdatedAt).max() else { return }
            if newest > (cursor ?? .distantPast) {
                try cursors.savePulledUpTo(newest, userId: userId, table: table)
                cursor = newest
            }

            // A full page that does not move the cursor means more rows share one timestamp than fit in a page; stop
            // instead of looping forever.
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
            // Only after the server accepts the batch, so a failed push is resent.
            try cursors.savePushedUpTo(mark, userId: userId, table: table)

            guard batch.rows.count >= pageSize, mark != cursor else { return }
            cursor = mark
        }
    }
}
