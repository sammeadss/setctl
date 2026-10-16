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
}
