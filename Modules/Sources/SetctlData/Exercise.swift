//
//  Exercise.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/22/26.
//

import Foundation
import GRDB

/// A catalog entry. Built-in exercises have no `ownerId`; custom ones carry their creator's.
public struct Exercise: Codable, Identifiable, FetchableRecord, PersistableRecord {
    public var id: String = UUID().uuidString
    public var name: String
    public var primaryMuscle: String
    public var isBodyweight: Bool
    public var isCustom: Bool
    public var ownerId: String?
    public var updatedAt: Date
    public var deletedAt: Date?
}
