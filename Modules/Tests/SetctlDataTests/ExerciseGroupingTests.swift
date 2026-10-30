//
//  ExerciseGroupingTests.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/27/26.
//

import Foundation
@testable import SetctlData
import Testing

@Test func groupsFollowTheDisplayOrderAndKeepEachGroupsOrder() {
    let exercises = [
        exercise("Squat", muscle: "quads"),
        exercise("Bench", muscle: "chest"),
        exercise("Fly", muscle: "chest"),
        exercise("Row", muscle: "back"),
    ]

    let groups = Exercise.grouped(exercises)

    #expect(groups.map(\.muscle) == ["chest", "back", "quads"])
    #expect(groups[0].exercises.map(\.name) == ["Bench", "Fly"])
}

@Test func emptyMuscleGroupsAreSkipped() {
    #expect(Exercise.grouped([exercise("Curl", muscle: "biceps")]).map(\.muscle) == ["biceps"])
    #expect(Exercise.grouped([]).isEmpty)
}

@Test func unknownMusclesComeLastAlphabetically() {
    let exercises = [
        exercise("Zeta", muscle: "neck"),
        exercise("Curl", muscle: "biceps"),
        exercise("Alpha", muscle: "balance"),
    ]

    #expect(Exercise.grouped(exercises).map(\.muscle) == ["biceps", "balance", "neck"])
}

private func exercise(_ name: String, muscle: String) -> Exercise {
    Exercise(
        name: name, primaryMuscle: muscle, isBodyweight: false, isCustom: false,
        ownerId: nil, updatedAt: Date(timeIntervalSince1970: 0), deletedAt: nil
    )
}
