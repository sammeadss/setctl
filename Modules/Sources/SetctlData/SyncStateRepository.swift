//
//  SyncStateRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
import GRDB

public enum SyncTable: String, CaseIterable, Sendable {
    case workout
    case workoutExercise
    case setEntry
}

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

public struct SyncStateRepository {
    private let database: AppDatabase

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

    public func claimOwner(_ userId: String) throws -> Bool {
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
}
