//
//  AppModel.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/23/26.
//

import Foundation
import Observation
import SetctlData
import StoreKit
import Supabase

@MainActor
@Observable
public final class AppModel {
    public let exerciseRepository: ExerciseRepository
    public let workoutRepository: WorkoutRepository
    public let authRepository: AuthRepository
    public let profileRepository: ProfileRepository
    public let entitlementRepository: EntitlementRepository
    public let remoteProfileRepository: RemoteProfileRepository
    private let syncService: SyncService
    public private(set) var authState: AuthState = .guest
    public private(set) var profile: Profile
    public private(set) var isPro: Bool = false
    public private(set) var serverIsPro: Bool = false
    public private(set) var proProduct: Product?
    public private(set) var syncStatus: SyncStatus = .off

    public init(database: AppDatabase, supabaseClient: SupabaseClient) throws {
        exerciseRepository = ExerciseRepository(database: database)
        workoutRepository = WorkoutRepository(database: database)
        authRepository = AuthRepository(client: supabaseClient)
        remoteProfileRepository = RemoteProfileRepository(client: supabaseClient)
        profileRepository = ProfileRepository(database: database)
        entitlementRepository = EntitlementRepository()
        profile = try profileRepository.fetchOrCreateProfile()
        syncService = SyncService(database: database, client: supabaseClient)

        Task {
            for await state in authRepository.stateChanges {
                authState = state
                await refreshServerIsPro()
            }
        }

        Task {
            for await isPro in entitlementRepository.entitlementUpdates {
                self.isPro = isPro
            }
        }

        Task {
            proProduct = try? await entitlementRepository.fetchProProduct()
        }
    }

    public func setUnits(_ units: String) {
        profile.units = units
        profile.updatedAt = Date()
        try? profileRepository.save(profile)
    }

    public func purchasePro() async {
        guard case let .signedIn(userId) = authState,
              let accountToken = UUID(uuidString: userId),
              let proProduct else { return }
        if await (try? entitlementRepository.purchase(proProduct, accountToken: accountToken)) == true {
            isPro = true
        }
    }

    public func requestSync() async {
        guard case let .signedIn(userId) = authState, serverIsPro else {
            syncStatus = .off
            return
        }
        syncStatus = .syncing
        let result: Result<SyncOutcome, any Error>
        do {
            result = try await .success(syncService.sync(userId: userId))
        } catch {
            result = .failure(error)
        }
        syncStatus = SyncStatus.from(result)
    }

    public func appDidBecomeActive() async {
        await refreshServerIsPro()
    }

    private func refreshServerIsPro() async {
        guard case let .signedIn(userId) = authState else {
            serverIsPro = false
            syncStatus = .off
            return
        }
        if let value = try? await remoteProfileRepository.fetchIsPro(userId: userId) {
            serverIsPro = value
        }
        Task { await requestSync() }
    }
}
