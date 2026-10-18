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
