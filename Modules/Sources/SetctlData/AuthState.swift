//
//  AuthState.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/5/26.
//

/// Whether the user has a signed-in account. A guest uses the whole app locally; sync needs an account.
public enum AuthState: Equatable {
    case guest
    case signedIn(userId: String)
}
