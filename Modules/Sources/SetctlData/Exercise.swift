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

/// Exercises of one muscle group, as listed in the picker.
public struct ExerciseGroup: Identifiable, Equatable {
    public let muscle: String
    public let exercises: [Exercise]
    public var id: String {
        muscle
    }
}

extension Exercise: Equatable {}

public extension Exercise {
    /// The muscle groups of the built-in catalog, in the order lists show them.
    static let muscleGroups = [
        "chest", "back", "shoulders", "biceps", "triceps", "forearms",
        "quads", "hamstrings", "glutes", "calves", "core",
    ]

    /// Groups exercises by muscle in display order, keeping each group's incoming order and skipping empty groups.
    /// Muscles outside `muscleGroups` come last, alphabetically.
    static func grouped(_ exercises: [Exercise]) -> [ExerciseGroup] {
        let byMuscle = Dictionary(grouping: exercises, by: \.primaryMuscle)
        let known = muscleGroups.filter { byMuscle[$0] != nil }
        let other = byMuscle.keys.filter { !muscleGroups.contains($0) }.sorted()
        return (known + other).map { ExerciseGroup(muscle: $0, exercises: byMuscle[$0] ?? []) }
    }
}
