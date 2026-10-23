//
//  SyncStateRepositoryTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/23/26.
//

import Foundation
@testable import SetctlData
import Testing

private let accountA = "7CD2758B-B159-47E0-B623-FD9D89440662"
private let accountB = "D3E821D6-3815-4FA1-8F62-A44D37F2CE4C"

@Test func clearingAnAccountReleasesItsClaimAndCursors() throws {
    let state = try SyncStateRepository(database: AppDatabase.empty())
    #expect(try state.claimOwner(accountA))
    try state.savePushedUpTo(Date(timeIntervalSince1970: 1_000_000), userId: accountA, table: .workout)

    try state.clear(forUser: accountA)

    #expect(try state.cursor(userId: accountA, table: .workout).pushedUpTo == nil)
    #expect(try state.claimOwner(accountB))
}

@Test func clearingAnotherAccountLeavesTheClaimAlone() throws {
    let state = try SyncStateRepository(database: AppDatabase.empty())
    #expect(try state.claimOwner(accountA))

    try state.clear(forUser: accountB)

    #expect(try state.claimOwner(accountA))
    #expect(try !state.claimOwner(accountB))
}
