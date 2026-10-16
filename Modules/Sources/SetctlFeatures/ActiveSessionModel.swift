//
//  ActiveSessionModel.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/24/26.
//

import Foundation
import Observation
import SetctlCore
import SetctlData

@Observable
final class ActiveSessionModel {
    private let workoutRepository: WorkoutRepository
    private(set) var workout: Workout
    private(set) var exercises: [SessionExercise] = []
    private var removedSets: [SetEntry] = []
    private(set) var saveFailed = false

    init(workoutRepository: WorkoutRepository) {
        self.workoutRepository = workoutRepository
        let now = Date()
        workout = Workout(
            startedAt: now,
            endedAt: nil,
            note: nil,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
    }

    init(
        resuming details: WorkoutDetails,
        workoutRepository: WorkoutRepository,
        exerciseRepository: ExerciseRepository
    ) throws {
        self.workoutRepository = workoutRepository
        workout = details.workout
        exercises = try details.exercises.map { item in
            let exerciseId = item.workoutExercise.exerciseId
            guard let exercise = try exerciseRepository.fetchExercise(id: exerciseId) else {
                throw ResumeError.missingExercise
            }
            return SessionExercise(
                exercise: exercise,
                previousSets: (try? workoutRepository.fetchLastSets(for: exercise.id)) ?? [],
                workoutExercise: item.workoutExercise,
                sets: item.sets
            )
        }
    }

    func addExercise(_ exercise: Exercise) {
        let workoutExercise = WorkoutExercise(
            workoutId: workout.id,
            exerciseId: exercise.id,
            position: exercises.count,
            updatedAt: Date(),
            deletedAt: nil
        )

        let previousSets = (try? workoutRepository.fetchLastSets(for: exercise.id)) ?? []

        exercises.append(SessionExercise(
            exercise: exercise,
            previousSets: previousSets,
            workoutExercise: workoutExercise,
            sets: []
        ))
        autosave()
    }

    func addSet(to sessionExerciseId: String, reps: Int, weight: Double) {
        guard let index = exercises.firstIndex(where: { $0.id == sessionExerciseId }) else { return }

        let now = Date()
        let set = SetEntry(
            workoutExerciseId: exercises[index].workoutExercise.id,
            position: exercises[index].sets.count,
            reps: reps,
            weight: weight,
            weightUnit: "kg",
            isWarmup: false,
            isCompleted: true,
            createdAt: now,
            updatedAt: now
        )

        exercises[index].sets.append(set)
        autosave()
    }

    func endSession() {
        let now = Date()
        workout.endedAt = now
        workout.updatedAt = now
        autosave()
    }

    func deleteSet(from sessionExerciseId: String, setId: String) {
        guard let index = exercises.firstIndex(where: { $0.id == sessionExerciseId }) else { return }
        guard let setIndex = exercises[index].sets.firstIndex(where: { $0.id == setId }) else { return }

        let now = Date()
        var removed = exercises[index].sets.remove(at: setIndex)
        removed.deletedAt = now
        removed.updatedAt = now
        removedSets.append(removed)

        renumberSets(at: index, now: now)
        autosave()
    }

    func moveSets(in sessionExerciseId: String, from source: IndexSet, to destination: Int) {
        guard let index = exercises.firstIndex(where: { $0.id == sessionExerciseId }) else { return }

        exercises[index].sets.move(fromOffsets: source, toOffset: destination)

        renumberSets(at: index, now: Date())
        autosave()
    }

    var totalSets: Int {
        exercises.flatMap(\.sets).count
    }

    var totalVolume: Double {
        WorkoutMath.totalVolume(of: exercises.flatMap(\.sets).map { (reps: $0.reps, weight: $0.weight) })
    }

    var duration: TimeInterval {
        guard let endedAt = workout.endedAt else { return 0 }
        return endedAt.timeIntervalSince(workout.startedAt)
    }

    private func renumberSets(at index: Int, now: Date) {
        for position in exercises[index].sets.indices {
            guard exercises[index].sets[position].position != position else { continue }
            exercises[index].sets[position].position = position
            exercises[index].sets[position].updatedAt = now
        }
    }

    private func autosave() {
        do {
            try workoutRepository.save(snapshot())
            saveFailed = false
        } catch {
            saveFailed = true
        }
    }

    private func snapshot() -> WorkoutDetails {
        WorkoutDetails(
            workout: workout,
            exercises: exercises.map { sessionExercise in
                WorkoutExerciseWithSets(
                    workoutExercise: sessionExercise.workoutExercise,
                    sets: sessionExercise.sets + removedSets.filter {
                        $0.workoutExerciseId == sessionExercise.workoutExercise.id
                    }
                )
            }
        )
    }
}

struct SessionExercise: Identifiable {
    let exercise: Exercise
    let previousSets: [SetEntry]
    var workoutExercise: WorkoutExercise
    var sets: [SetEntry]
    var id: String {
        workoutExercise.id
    }
}

enum ResumeError: Error {
    case missingExercise
}
