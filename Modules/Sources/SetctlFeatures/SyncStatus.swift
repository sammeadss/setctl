//
//  SyncStatus.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/18/26.
//

import Foundation
import SetctlData

public enum SyncStatus: Equatable, Sendable {
    case off
    case idle
    case syncing
    case synced(Date)
    case failed
    case wrongAccount

    static func from(_ result: Result<SyncOutcome, any Error>, now: Date = Date()) -> SyncStatus {
        switch result {
        case let .success(outcome):
            outcome == .synced ? .synced(now) : .idle
        case let .failure(error):
            (error as? SyncError) == .deviceBelongsToAnotherAccount ? .wrongAccount : .failed
        }
    }
}

extension SyncStatus {
    var displayText: String? {
        switch self {
        case .off:
            nil
        case .idle:
            "SYNC: READY"
        case .syncing:
            "SYNCING..."
        case let .synced(date):
            "SYNCED: " + date.formatted(date: .omitted, time: .shortened)
        case .failed:
            "SYNC FAILED. WILL RETRY."
        case .wrongAccount:
            "THIS DEVICE BELONGS TO ANOTHER ACCOUNT. SYNC IS OFF."
        }
    }

    var isWarning: Bool {
        self == .failed || self == .wrongAccount
    }

    var canSyncNow: Bool {
        switch self {
        case .idle, .synced, .failed:
            true
        case .off, .syncing, .wrongAccount:
            false
        }
    }
}
