//
//  SyncStore.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
import GRDB

extension Workout: SyncRecord {}
extension WorkoutExercise: SyncRecord {}
extension SetEntry: SyncRecord {}

/// The result of a push query: the rows to send and the newest `updatedAt` among them, which becomes the push cursor
/// once the server acknowledges the batch.
struct PushBatch<Row: SyncRow> {
    var rows: [Row]
    var highWaterMark: Date?
}

/// The local-database side of sync: finds rows to push and applies pulled rows.
struct SyncStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    /// Applies pulled rows, keeping the local copy when it is as new or newer.
    func applyRemote<Row: SyncRow>(_ rows: [Row]) throws {
        try database.write { db in
            for row in rows {
                let incoming = row.local
                let existing = try Row.Local.fetchOne(db, key: incoming.id)
                if let existing, existing.updatedAt >= incoming.updatedAt {
                    continue
                }
                try incoming.save(db)
            }
        }
    }

    /// Local rows changed at or after `since`, oldest first.
    func changedRows<Row: SyncRow>(
        _: Row.Type,
        since: Date?,
        limit: Int,
        userId: String
    ) throws -> PushBatch<Row> {
        try database.read { db in
            var request = Row.Local.all()
            if let since {
                // Inclusive: the boundary row is resent, which is harmless because upserts are idempotent.
                request = request.filter(Column("updatedAt") >= since)
            }
            var records = try request
                .order(Column("updatedAt"), Column("id"))
                .limit(limit)
                .fetchAll(db)

            if records.count == limit, let last = records.last {
                // A full page can cut through rows sharing one `updatedAt`; take the rest of the run so the cursor
                // never moves past an unsent row.
                let seen = Set(records.map(\.id))
                let run = try Row.Local
                    .filter(Column("updatedAt") == last.updatedAt)
                    .fetchAll(db)
                records += run.filter { !seen.contains($0.id) }
            }

            return PushBatch(
                rows: records.map { Row($0, userId: userId) },
                highWaterMark: records.last?.updatedAt
            )
        }
    }
}
