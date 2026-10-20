//
//  SyncRemote.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/16/26.
//

import Foundation
import Supabase

/// The network side of sync, a protocol so the engine can be tested without a server.
protocol SyncRemote: Sendable {
    /// Upserts rows by `id`; the server ignores rows older than its stored copy.
    func push(_ rows: [some SyncRow]) async throws
    func pull<Row: SyncRow>(_ type: Row.Type, since: Date, limit: Int) async throws -> [Row]
}

struct SupabaseSyncRemote: SyncRemote {
    let client: SupabaseClient

    func push<Row: SyncRow>(_ rows: [Row]) async throws {
        guard !rows.isEmpty else { return }
        try await client
            .from(Row.remoteTable)
            .upsert(rows, returning: .minimal)
            .execute()
    }

    func pull<Row: SyncRow>(_: Row.Type, since: Date, limit: Int) async throws -> [Row] {
        // Filter on the server's clock (`server_updated_at`), not the device's: a skewed
        // device cannot slip a row behind other devices' cursors.
        try await client
            .from(Row.remoteTable)
            .select()
            .gte("server_updated_at", value: since)
            .order("server_updated_at", ascending: true)
            .limit(limit)
            .execute()
            .value
    }
}
