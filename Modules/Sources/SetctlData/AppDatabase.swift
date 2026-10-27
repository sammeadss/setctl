//
//  AppDatabase.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/21/26.
//

import Foundation
import GRDB

/// The app's SQLite database. Creating one applies all pending migrations.
public struct AppDatabase: Sendable {
    private let dbWriter: any DatabaseWriter

    init(_ dbWriter: some DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
            // Wipes the database when an already-registered migration is edited. Release
            // builds must only ever add new migrations.
            migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1: initial schema") { db in
            try db.create(table: "profile") { t in
                t.primaryKey("id", .text)
                t.column("units", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
            }
            try db.create(table: "exercise") { t in
                t.primaryKey("id", .text)
                t.column("name", .text).notNull()
                t.column("primaryMuscle", .text).notNull()
                t.column("isBodyweight", .boolean).notNull()
                t.column("isCustom", .boolean).notNull()
                t.column("ownerId", .text)
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }
            try db.create(table: "workout") { t in
                t.primaryKey("id", .text)
                t.column("startedAt", .datetime).notNull()
                t.column("endedAt", .datetime)
                t.column("note", .text)
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }
            try db.create(table: "workoutExercise") { t in
                t.primaryKey("id", .text)
                t.belongsTo("workout", onDelete: .cascade).notNull()
                t.belongsTo("exercise").notNull()
                t.column("position", .integer).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }
            try db.create(table: "setEntry") { t in
                t.primaryKey("id", .text)
                t.belongsTo("workoutExercise", onDelete: .cascade).notNull()
                t.column("position", .integer).notNull()
                t.column("reps", .integer).notNull()
                t.column("weight", .double).notNull()
                t.column("weightUnit", .text).notNull()
                t.column("rpe", .double)
                t.column("isWarmup", .boolean).notNull()
                t.column("isCompleted", .boolean).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("updatedAt", .datetime).notNull()
                t.column("deletedAt", .datetime)
            }
        }

        migrator.registerMigration("v2: seed exercise catalog") { db in
            // Fixed IDs and an epoch timestamp keep the catalog identical on every install.
            let seededAt = Date(timeIntervalSince1970: 0)
            let exercises = [
                Exercise(
                    id: "00000000-0000-0000-0000-000000000001",
                    name: "Barbell Bench Press",
                    primaryMuscle: "chest",
                    isBodyweight: false,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000002",
                    name: "Barbell Back Squat",
                    primaryMuscle: "legs",
                    isBodyweight: false,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000003",
                    name: "Bent-Over Barbell Row",
                    primaryMuscle: "back",
                    isBodyweight: false,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000004",
                    name: "Pec Deck",
                    primaryMuscle: "chest",
                    isBodyweight: false,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000005",
                    name: "Barbell Overhead Press",
                    primaryMuscle: "shoulders",
                    isBodyweight: false,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000006",
                    name: "Pull-Up",
                    primaryMuscle: "back",
                    isBodyweight: true,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000007",
                    name: "Push-Up",
                    primaryMuscle: "chest",
                    isBodyweight: true,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
                Exercise(
                    id: "00000000-0000-0000-0000-000000000008",
                    name: "Dip",
                    primaryMuscle: "chest",
                    isBodyweight: true,
                    isCustom: false,
                    ownerId: nil,
                    updatedAt: seededAt,
                    deletedAt: nil
                ),
            ]
            for exercise in exercises {
                try exercise.insert(db)
            }
        }

        migrator.registerMigration("v3: sync state") { db in
            // Per-account sync cursors.
            try db.create(table: "syncState") { t in
                t.column("userId", .text).notNull()
                t.column("tableName", .text).notNull()
                t.column("pushedUpTo", .datetime)
                t.column("pulledUpTo", .datetime)
                t.primaryKey(["userId", "tableName"])
            }
        }

        migrator.registerMigration("v4: drop the unused rpe column") { db in
            try db.alter(table: "setEntry") { t in
                t.drop(column: "rpe")
            }
        }

        return migrator
    }

    func write<T>(_ updates: (Database) throws -> T) throws -> T {
        try dbWriter.write(updates)
    }

    func read<T>(_ value: (Database) throws -> T) throws -> T {
        try dbWriter.read(value)
    }

    /// An in-memory database for tests and previews.
    public static func empty() throws -> AppDatabase {
        try AppDatabase(DatabaseQueue())
    }

    /// The on-disk database in Application Support, created on first use.
    public static func makeShared() throws -> AppDatabase {
        let fileManager = FileManager.default
        // Application Support is backed up and never purged by the system.
        let appSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directoryURL = appSupportURL.appendingPathComponent("database", isDirectory: true)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let databaseURL = directoryURL.appendingPathComponent("setctl.sqlite")
        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        return try AppDatabase(dbQueue)
    }
}
