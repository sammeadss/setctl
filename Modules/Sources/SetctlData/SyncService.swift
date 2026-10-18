//
//  SyncService.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/18/26.
//

import Supabase

public struct SyncService: Sendable {
    private let engine: SyncEngine

    public init(database: AppDatabase, client: SupabaseClient) {
        engine = SyncEngine(remote: SupabaseSyncRemote(client: client), database: database)
    }

    @discardableResult
    public func sync(userId: String) async throws -> SyncOutcome {
        try await engine.sync(userId: userId)
    }
}
