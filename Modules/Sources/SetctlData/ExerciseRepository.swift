//
//  ExerciseRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/23/26.
//

import Foundation
import GRDB

public struct ExerciseRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchAllExercises() throws -> [Exercise] {
        try database.read { db in
            try Exercise
                .filter(Column("deletedAt") == nil)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    /// Returns the exercise even if it is soft-deleted, so past workouts can still show its name.
    public func fetchExercise(id: String) throws -> Exercise? {
        try database.read { db in
            try Exercise.fetchOne(db, id: id)
        }
    }
}
