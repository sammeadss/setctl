//
//  SyncStateRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
import GRDB

/// Synced tables, parents first; the engine pushes and pulls in this order because of server foreign keys.
public enum SyncTable: String, CaseIterable, Sendable {
    case workout
    case workoutExercise
    case setEntry
}

/// Sync progress for one table. `pushedUpTo` is a local `updatedAt`; `pulledUpTo` is a server-assigned
/// `server_updated_at`. They are different clocks and never compared.
public struct SyncCursor: Equatable, Sendable {
    public var pushedUpTo: Date?
    public var pulledUpTo: Date?
}

struct SyncState: Codable, FetchableRecord, PersistableRecord {
    var userId: String
    var tableName: String
    var pushedUpTo: Date?
    var pulledUpTo: Date?
}

/// Persists the per-table sync cursors and the device's owning account.
public struct SyncStateRepository {
    private let database: AppDatabase

    /// The device owner is stored as a row with this sentinel table name.
    private static let ownerKey = "owner"

    public init(database: AppDatabase) {
        self.database = database
    }

    public func cursor(userId: String, table: SyncTable) throws -> SyncCursor {
        try database.read { db in
            let state = try fetch(userId: userId, table: table, in: db)
            return SyncCursor(pushedUpTo: state?.pushedUpTo, pulledUpTo: state?.pulledUpTo)
        }
    }

    /// Advances the push cursor. Call only after the server acknowledges the batch, so a failure resends rather than
    /// skips.
    public func savePushedUpTo(_ date: Date, userId: String, table: SyncTable) throws {
        try update(userId: userId, table: table) { $0.pushedUpTo = date }
    }

    public func savePulledUpTo(_ date: Date, userId: String, table: SyncTable) throws {
        try update(userId: userId, table: table) { $0.pulledUpTo = date }
    }

    private func fetch(userId: String, table: SyncTable, in db: Database) throws -> SyncState? {
        try SyncState.fetchOne(db, key: ["userId": userId, "tableName": table.rawValue])
    }

    private func update(
        userId: String,
        table: SyncTable,
        _ change: (inout SyncState) -> Void
    ) throws {
        try database.write { db in
            var state = try fetch(userId: userId, table: table, in: db)
                ?? SyncState(userId: userId, tableName: table.rawValue)
            change(&state)
            try state.upsert(db)
        }
    }

    /// Claims the device for `userId` if it is unclaimed; returns whether `userId` owns it.
    public func claimOwner(_ userId: String) throws -> Bool {
        // Swift UUID strings are uppercase and Postgres returns lowercase.
        let candidate = userId.uppercased()
        return try database.write { db in
            let existing = try SyncState
                .filter(Column("tableName") == Self.ownerKey)
                .fetchOne(db)
            if let existing {
                return existing.userId == candidate
            }
            try SyncState(userId: candidate, tableName: Self.ownerKey).insert(db)
            return true
        }
    }

    /// Releases the device claim and clears the cursors of `userId`, for when that account is deleted. Another
    /// account's claim is left alone.
    public func clear(forUser userId: String) throws {
        try database.write { db in
            _ = try SyncState.filter(Column("userId") == userId.uppercased()).deleteAll(db)
        }
    }
}
