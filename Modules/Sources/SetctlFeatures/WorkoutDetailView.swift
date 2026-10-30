//
//  WorkoutDetailView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/5/26.
//

import SetctlCore
import SetctlData
import SetctlDesignSystem
import SwiftUI

public struct WorkoutDetailView: View {
    @Environment(AppModel.self) private var appModel
    let workoutId: String

    @State private var details: WorkoutDetails?
    @State private var exerciseNames: [String: String] = [:]

    public init(workoutId: String) {
        self.workoutId = workoutId
    }

    public var body: some View {
        ZStack {
            Palette.black.ignoresSafeArea()

            if let details {
                List {
                    ForEach(details.exercises, id: \.workoutExercise.id) { exerciseWithSets in
                        Section {
                            ForEach(exerciseWithSets.sets) { set in
                                Text(appModel.weightUnit.formatSet(reps: set.reps, kilograms: set.weight))
                                    .font(Typography.label)
                                    .foregroundStyle(Palette.greenDim)
                            }
                            .listRowBackground(Color.clear)
                        } header: {
                            Text(exerciseNames[exerciseWithSets.workoutExercise.exerciseId] ?? "Exercise")
                                .font(Typography.body)
                                .foregroundStyle(Palette.green)
                        } footer: {
                            let volume = exerciseVolume(for: exerciseWithSets)
                            if volume > 0 {
                                Text(appModel.weightUnit.format(kilograms: volume))
                                    .font(Typography.label)
                                    .foregroundStyle(Palette.greenDim)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .task {
            do {
                details = try appModel.workoutRepository.fetchDetails(id: workoutId)
                // A workout stores only exercise ids, so names come from the catalog.
                let exercises = try appModel.exerciseRepository.fetchAllExercises()
                exerciseNames = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })
            } catch {
                AppLog.ui.error("Failed to load workout detail: \(error)")
            }
        }
    }

    private func exerciseVolume(for exerciseWithSets: WorkoutExerciseWithSets) -> Double {
        WorkoutMath.totalVolume(of: exerciseWithSets.sets.map { (reps: $0.reps, weight: $0.weight) })
    }
}
