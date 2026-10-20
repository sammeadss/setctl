//
//  ProfileRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/6/26.
//

import Foundation
import GRDB

/// The local profile (preferences).
public struct ProfileRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    /// Returns the profile, creating it with kilogram units on first launch.
    public func fetchOrCreateProfile() throws -> Profile {
        try database.write { db in
            if let existing = try Profile.fetchOne(db) {
                return existing
            }
            let now = Date()
            let profile = Profile(units: "kg", createdAt: now, updatedAt: now)
            try profile.insert(db)
            return profile
        }
    }

    public func save(_ profile: Profile) throws {
        try database.write { db in
            try profile.save(db)
        }
    }
}
