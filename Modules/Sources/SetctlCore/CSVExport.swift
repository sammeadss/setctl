//
//  CSVExport.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/23/26.
//

import Foundation

/// One logged set, flattened for export.
public struct SetExportRow: Equatable, Sendable {
    public let workoutDate: Date
    public let exercise: String
    public let setNumber: Int
    public let reps: Int
    public let weightKilograms: Double
    public let isWarmup: Bool

    public init(
        workoutDate: Date,
        exercise: String,
        setNumber: Int,
        reps: Int,
        weightKilograms: Double,
        isWarmup: Bool
    ) {
        self.workoutDate = workoutDate
        self.exercise = exercise
        self.setNumber = setNumber
        self.reps = reps
        self.weightKilograms = weightKilograms
        self.isWarmup = isWarmup
    }
}

/// Builds the CSV for the data export.
public enum CSVExport {
    /// A header plus one line per set, with weights in `unit`.
    public static func make(from rows: [SetExportRow], unit: WeightUnit) -> String {
        let header = "date,exercise,set,reps,weight,unit,warmup"
        let dateFormatter = ISO8601DateFormatter()
        let lines = rows.map { row in
            [
                dateFormatter.string(from: row.workoutDate),
                escaped(row.exercise),
                String(row.setNumber),
                String(row.reps),
                String(format: "%.2f", unit.fromKilograms(row.weightKilograms)),
                unit.rawValue,
                row.isWarmup ? "true" : "false",
            ].joined(separator: ",")
        }
        return ([header] + lines).joined(separator: "\n") + "\n"
    }

    /// Quotes a field containing a comma, quote, or newline, doubling any embedded quotes.
    private static func escaped(_ field: String) -> String {
        guard field.contains(where: { ",\"\n\r".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
