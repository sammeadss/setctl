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
            // The anon key is public by design; access is enforced by RLS.
            // swiftlint:disable:next line_length
            supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzYnl5aHdzdWpyZm56Z3hqdmx3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTEyMzg1NDEsImV4cCI6MjEwNjgxNDU0MX0.MJWTGvIxyM2WIua7AumIFF0W6MBxxvJV7-luCDUOy64",
            options: SupabaseClientOptions(
                // Emits the stored session at launch even if expired; `AuthRepository` checks `isExpired`.
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }
}
