//
//  AuthRepository.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/5/26.
//

import Supabase

/// Email and password authentication through Supabase.
public struct AuthRepository: Sendable {
    private let client: SupabaseClient

    public init(client: SupabaseClient) {
        self.client = client
    }

    public func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    public func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    public func signOut() async throws {
        try await client.auth.signOut()
    }

    /// Emits the current auth state, then every change. An expired stored session counts as a guest.
    public var stateChanges: AsyncStream<AuthState> {
        AsyncStream { continuation in
            let task = Task {
                for await (_, session) in client.auth.authStateChanges {
                    if let session, !session.isExpired {
                        continuation.yield(.signedIn(userId: session.user.id.uuidString))
                    } else {
                        continuation.yield(.guest)
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
