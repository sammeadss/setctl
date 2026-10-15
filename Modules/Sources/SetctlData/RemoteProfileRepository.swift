//
//  RemoteProfileRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/14/26.
//

import Supabase

public struct RemoteProfileRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

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
