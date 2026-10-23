//
//  AppModel.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/23/26.
//

import Foundation
import Observation
import SetctlCore
import SetctlData
import StoreKit
import Supabase

/// App-wide state shared through the environment: repositories, auth, Pro status, and sync status. Also decides when to
/// sync.
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
    /// Pro according to StoreKit on this device.
    public private(set) var isPro: Bool = false
    /// Pro according to the server profile. Sync runs only when this is true.
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

        // Listeners for auth and entitlement changes, alive as long as the app.
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

    /// The unit weights are shown and entered in. Falls back to kilograms for an unrecognized stored value.
    public var weightUnit: WeightUnit {
        WeightUnit(rawValue: profile.units) ?? .kg
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
        // Tags the purchase with the user's id so a receipt can be tied to the account.
        if await (try? entitlementRepository.purchase(proProduct, accountToken: accountToken)) == true {
            isPro = true
        }
    }

    /// Syncs now when signed in with a Pro account, otherwise sets the status to off. Failures are reported through
    /// `syncStatus`, not thrown.
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

    /// Refreshes the server's Pro flag, which then triggers a sync.
    public func appDidBecomeActive() async {
        await refreshServerIsPro()
    }

    private func refreshServerIsPro() async {
        guard case let .signedIn(userId) = authState else {
            serverIsPro = false
            syncStatus = .off
            return
        }
        // Keep the last known value if the fetch fails, such as when offline.
        if let value = try? await remoteProfileRepository.fetchIsPro(userId: userId) {
            serverIsPro = value
        }
        Task { await requestSync() }
    }
}
