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
