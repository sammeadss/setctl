//
//  SupabaseConfig.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/5/26.
//

import Foundation
import Supabase

public enum SupabaseConfig {
    public static func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: URL(string: "https://usbyyhwsujrfnzgxjvlw.supabase.co")!,
            supabaseKey: "sb_publishable_kG7hT1E3r3yu1AHtGA_eJQ_H81uZadO",
            options: SupabaseClientOptions(
                // Emits the stored session at launch even if expired; `AuthRepository` checks `isExpired`.
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
