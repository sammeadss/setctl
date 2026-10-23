//
//  SessionExerciseRow.swift
//  SetctlModules
//
//  Created by Samuel Meads on 8/5/26.
//

import SetctlCore
import SetctlData
import SetctlDesignSystem
import SwiftUI

struct SessionExerciseRow: View {
    let item: SessionExercise
    let unit: WeightUnit
    let onAddSet: (Int, Double) -> Void
    let onDeleteSet: (String) -> Void
    let onMoveSets: (IndexSet, Int) -> Void

    @State private var reps: Int
    @State private var weight: Double

    init(
        item: SessionExercise,
        unit: WeightUnit,
        onAddSet: @escaping (Int, Double) -> Void,
        onDeleteSet: @escaping (String) -> Void,
        onMoveSets: @escaping (IndexSet, Int) -> Void
    ) {
        self.item = item
        self.unit = unit
        self.onAddSet = onAddSet
        self.onDeleteSet = onDeleteSet
        self.onMoveSets = onMoveSets
        _reps = State(initialValue: item.previousSets.first?.reps ?? 8)
        let lastWeight = item.previousSets.first.map { unit.fromKilograms($0.weight) }
        _weight = State(initialValue: lastWeight ?? (unit == .kg ? 20 : 45))
    }

    private var weightStep: Double {
        unit == .kg ? 2.5 : 5
    }

    private var lastWorkoutSummary: String {
        "LAST: " + item.previousSets
            .map { "\($0.reps)×\(unit.format(kilograms: $0.weight))" }
            .joined(separator: ", ")
    }

    var body: some View {
        Text(item.exercise.name)
            .font(Typography.body)
            .foregroundStyle(Palette.green)

        if !item.previousSets.isEmpty {
            Text(lastWorkoutSummary)
                .font(Typography.label)
                .foregroundStyle(Palette.greenDim)
        }

        ForEach(item.sets) { set in
            Text("\(set.reps) x \(unit.format(kilograms: set.weight))")
                .font(Typography.label)
                .foregroundStyle(Palette.greenDim)
        }
        .onDelete { offsets in
            for index in offsets {
                onDeleteSet(item.sets[index].id)
            }
        }
        .onMove { source, destination in
            onMoveSets(source, destination)
        }

        Stepper("\(reps) reps", value: $reps, in: 1 ... 50)
            .font(Typography.label)
            .foregroundStyle(Palette.green)

        Stepper(
            "\(weight, specifier: "%.1f") \(unit.rawValue)",
            value: $weight,
            in: 0 ... unit.fromKilograms(500),
            step: weightStep
        )
        .font(Typography.label)
        .foregroundStyle(Palette.green)

        Button("+ ADD SET") {
            // The row works in the display unit; the model stores kilograms.
            onAddSet(reps, unit.toKilograms(weight))
        }
        .font(Typography.label)
        .foregroundStyle(Palette.green)
    }
}
