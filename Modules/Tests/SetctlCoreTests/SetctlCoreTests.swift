import Foundation
@testable import SetctlCore
import Testing

@Test func totalVolumeSumsRepsTimesWeight() {
    let sets = [(reps: 10, weight: 100.0), (reps: 5, weight: 200.0)]
    #expect(WorkoutMath.totalVolume(of: sets) == 2000)
}

@Test func totalVolumeOfNoSetsIsZero() {
    #expect(WorkoutMath.totalVolume(of: []) == 0)
}

@Test func kilogramsAreUnchangedInKilograms() {
    #expect(WeightUnit.kg.fromKilograms(100) == 100)
    #expect(WeightUnit.kg.toKilograms(100) == 100)
}

@Test func convertsKilogramsToPounds() {
    #expect(abs(WeightUnit.lb.fromKilograms(100) - 220.462) < 0.001)
}

@Test func poundsRoundTripThroughKilograms() {
    let kilograms = WeightUnit.lb.toKilograms(225)
    #expect(abs(WeightUnit.lb.fromKilograms(kilograms) - 225) < 1e-9)
}

@Test func formatsWeightInTheChosenUnit() {
    #expect(WeightUnit.kg.format(kilograms: 100) == "100.0kg")
    #expect(WeightUnit.lb.format(kilograms: 100) == "220.5lb")
}

@Test func csvHasAHeaderAndOneLinePerSet() {
    let csv = CSVExport.make(from: [sampleRow()], unit: .kg)
    #expect(csv == "date,exercise,set,reps,weight,unit,warmup\n1970-01-01T00:00:00Z,Squat,1,5,100.00,kg,false\n")
}

@Test func csvOfNoSetsIsJustTheHeader() {
    #expect(CSVExport.make(from: [], unit: .kg) == "date,exercise,set,reps,weight,unit,warmup\n")
}

@Test func csvConvertsWeightToTheChosenUnit() {
    let csv = CSVExport.make(from: [sampleRow()], unit: .lb)
    #expect(csv.contains(",220.46,lb,"))
}

@Test func csvQuotesFieldsWithCommasAndQuotes() {
    let csv = CSVExport.make(from: [sampleRow(exercise: "Press, \"strict\"")], unit: .kg)
    #expect(csv.contains("\"Press, \"\"strict\"\"\""))
}

@Test func formatsASetWithItsWeight() {
    #expect(WeightUnit.kg.formatSet(reps: 8, kilograms: 100) == "8 x 100.0kg")
}

@Test func formatsAnUnweightedSetAsRepsOnly() {
    #expect(WeightUnit.lb.formatSet(reps: 12, kilograms: 0) == "12 reps")
}

private func sampleRow(exercise: String = "Squat", kilograms: Double = 100) -> SetExportRow {
    SetExportRow(
        workoutDate: Date(timeIntervalSince1970: 0),
        exercise: exercise,
        setNumber: 1,
        reps: 5,
        weightKilograms: kilograms,
        isWarmup: false
    )
}
