//
//  ExerciseCatalog.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/27/26.
//

import Foundation
import GRDB

/// The built-in exercise catalog, read from the bundled `exercise-catalog.json`.
enum ExerciseCatalog {
    struct Entry: Decodable, Equatable {
        let id: String
        let name: String
        let muscle: String
        let bodyweight: Bool
    }

    static let muscles = Set(Exercise.muscleGroups)

    static func load() throws -> [Entry] {
        guard let url = Bundle.module.url(forResource: "exercise-catalog", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([Entry].self, from: Data(contentsOf: url))
    }

    /// Makes the `exercise` table match the catalog: inserts new entries and updates existing ones by id. Safe to run
    /// again, and it never deletes, so logged workouts keep their exercises.
    static func sync(into db: Database) throws {
        // A fixed timestamp keeps the catalog identical on every install.
        let seededAt = Date(timeIntervalSince1970: 0)
        for entry in try load() {
            try Exercise(
                id: entry.id,
                name: entry.name,
                primaryMuscle: entry.muscle,
                isBodyweight: entry.bodyweight,
                isCustom: false,
                ownerId: nil,
                updatedAt: seededAt,
                deletedAt: nil
            ).save(db)
        }
    }
}
