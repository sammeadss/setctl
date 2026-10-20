//
//  Workout.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/22/26.
//

import Foundation
import GRDB

/// A single training session.
///
/// Rows are soft-deleted: set `deletedAt` rather than removing the row, so sync can
/// propagate the deletion. Bump `updatedAt` on every change, since it is the sync cursor.
public struct Workout: Codable, Identifiable, Equatable, FetchableRecord, PersistableRecord {
    public var id: String = UUID().uuidString
    public var startedAt: Date
    /// `nil` while the workout is in progress.
    public var endedAt: Date?
    public var note: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: String = UUID().uuidString,
        startedAt: Date,
        endedAt: Date? = nil,
        note: String? = nil,
        createdAt: Date,
        updatedAt: Date,
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }
}
