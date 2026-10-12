//
//  AppModel.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/23/26.
//

import Foundation
import Observation
import SetctlData
import Supabase

@MainActor
@Observable
public final class AppModel {
    public let exerciseRepository: ExerciseRepository
    public let workoutRepository: WorkoutRepository
    public let authRepository: AuthRepository
    public let profileRepository: ProfileRepository
    public let entitlementRepository: EntitlementRepository
    public private(set) var authState: AuthState = .guest
    public private(set) var profile: Profile
    public private(set) var isPro: Bool = false

    public init(database: AppDatabase, supabaseClient: SupabaseClient) throws {
        exerciseRepository = ExerciseRepository(database: database)
        workoutRepository = WorkoutRepository(database: database)
        authRepository = AuthRepository(client: supabaseClient)
        profileRepository = ProfileRepository(database: database)
        entitlementRepository = EntitlementRepository()
        profile = try profileRepository.fetchOrCreateProfile()

        Task {
            for await state in authRepository.stateChanges {
                authState = state
            }
        }

        Task {
            for await isPro in entitlementRepository.entitlementUpdates {
                self.isPro = isPro
            }
        }
    }

    public func setUnits(_ units: String) {
        profile.units = units
        profile.updatedAt = Date()
        try? profileRepository.save(profile)
    }
}
