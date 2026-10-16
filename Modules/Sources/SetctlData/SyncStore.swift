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

struct PushBatch<Row: SyncRow> {
    var rows: [Row]
    var highWaterMark: Date?
}

struct SyncStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

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

    func changedRows<Row: SyncRow>(
        _: Row.Type,
        since: Date?,
        limit: Int,
        userId: String
    ) throws -> PushBatch<Row> {
        try database.read { db in
            var request = Row.Local.all()
            if let since {
                request = request.filter(Column("updatedAt") >= since)
            }
            var records = try request
                .order(Column("updatedAt"), Column("id"))
                .limit(limit)
                .fetchAll(db)

            if records.count == limit, let last = records.last {
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
