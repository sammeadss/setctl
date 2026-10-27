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

    private enum Field {
        case reps, weight
    }

    // Plain text, not `TextField(value:format:)`, which commits when editing ends and could miss a value typed just
    // before tapping ADD SET.
    @State private var repsText = ""
    @State private var weightText = ""
    @FocusState private var focusedField: Field?

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
    }

    private var reps: Int? {
        guard let value = Int(repsText), (1 ... 999).contains(value) else { return nil }
        return value
    }

    /// The typed weight in the display unit. Bodyweight exercises log reps only, and an empty field also counts as 0.
    private var weight: Double? {
        guard !item.exercise.isBodyweight, !weightText.isEmpty else { return 0 }
        guard let value = try? Double(weightText, format: .number), (0 ... 9999).contains(value) else { return nil }
        return value
    }

    var body: some View {
        Text(item.exercise.name)
            .font(Typography.body)
            .foregroundStyle(Palette.green)

        ForEach(item.sets) { set in
            Text(unit.formatSet(reps: set.reps, kilograms: set.weight))
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

        HStack {
            TextField("0", text: $repsText, prompt: Text("0").foregroundStyle(Palette.greenDim))
                .focused($focusedField, equals: .reps)
                .multilineTextAlignment(.trailing)
            #if os(iOS)
                .keyboardType(.numberPad)
            #endif
            Text("reps")
        }
        .font(Typography.label)
        .foregroundStyle(Palette.green)
        .tint(Palette.green)

        if !item.exercise.isBodyweight {
            HStack {
                TextField("0", text: $weightText, prompt: Text("0").foregroundStyle(Palette.greenDim))
                    .focused($focusedField, equals: .weight)
                    .multilineTextAlignment(.trailing)
                #if os(iOS)
                    .keyboardType(.decimalPad)
                #endif
                Text(unit.rawValue)
            }
            .font(Typography.label)
            .foregroundStyle(Palette.green)
            .tint(Palette.green)
        }

        Button("+ ADD SET") {
            guard let reps, let weight else { return }
            // The row works in the display unit; the model stores kilograms.
            onAddSet(reps, unit.toKilograms(weight))
            repsText = ""
            weightText = ""
            focusedField = .reps
        }
        .font(Typography.label)
        .foregroundStyle(Palette.green)
        .disabled(reps == nil || weight == nil)
    }
}
