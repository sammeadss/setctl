//
//  MigrationTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/27/26.
//

import Foundation
import GRDB
@testable import SetctlData
import Testing

@Test func droppingRpeKeepsExistingSets() throws {
    let queue = try DatabaseQueue()
    try AppDatabase.migrator.migrate(queue, upTo: "v3: sync state")
    try queue.write { db in
        try db.execute(sql: """
        INSERT INTO workout (id, startedAt, createdAt, updatedAt)
        VALUES ('W', '2026-01-01 00:00:00.000', '2026-01-01 00:00:00.000', '2026-01-01 00:00:00.000')
        """)
        try db.execute(sql: """
        INSERT INTO workoutExercise (id, workoutId, exerciseId, position, updatedAt)
        VALUES ('WE', 'W', '00000000-0000-0000-0000-000000000001', 0, '2026-01-01 00:00:00.000')
        """)
        try db.execute(sql: """
        INSERT INTO setEntry
        (id, workoutExerciseId, position, reps, weight, weightUnit, rpe, isWarmup, isCompleted, createdAt, updatedAt)
        VALUES ('S', 'WE', 0, 5, 100.0, 'kg', 8.0, 0, 1, '2026-01-01 00:00:00.000', '2026-01-01 00:00:00.000')
        """)
    }

    try AppDatabase.migrator.migrate(queue)

    try queue.read { db in
        #expect(try !db.columns(in: "setEntry").map(\.name).contains("rpe"))
        let row = try #require(try Row.fetchOne(db, sql: "SELECT reps, weight FROM setEntry WHERE id = 'S'"))
        let reps: Int = row["reps"]
        let weight: Double = row["weight"]
        #expect(reps == 5)
        #expect(weight == 100)
    }
}
