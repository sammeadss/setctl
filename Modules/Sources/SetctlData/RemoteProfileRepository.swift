//
//  RemoteProfileRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/14/26.
//

import Supabase

/// Reads the signed-in user's server-side profile.
public struct RemoteProfileRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    /// Whether the server marks the user as Pro. The app uses this for UI only; the server enforces the tier with RLS.
    public func fetchIsPro(userId: String) async throws -> Bool {
        let row: ProfileRow = try await client
            .from("profiles")
            .select("is_pro")
            .eq("id", value: userId)
            .single()
            .execute()
            .value
        return row.isPro
    }
}

private struct ProfileRow: Decodable {
    let isPro: Bool

    enum CodingKeys: String, CodingKey {
        case isPro = "is_pro"
    }
}
