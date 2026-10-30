//
//  HistoryView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/5/26.
//

import SetctlCore
import SetctlData
import SetctlDesignSystem
import SwiftUI

public struct HistoryView: View {
    @Environment(AppModel.self) private var appModel
    @State private var summaries: [WorkoutSummary] = []
    @AppStorage(StorageKey.scanlinesEnabled) private var isScanlinesEnabled = true

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Palette.black.ignoresSafeArea()

                List(summaries) { summary in
                    NavigationLink(value: summary.id) {
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(summary.startedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(Typography.body)
                                .foregroundStyle(Palette.green)

                            Text(detailText(for: summary))
                                .font(Typography.label)
                                .foregroundStyle(Palette.greenDim)
                        }
                        .scanlines(isEnabled: isScanlinesEnabled)
                    }
                    .listRowBackground(Color.clear)
                }
                .scrollContentBackground(.hidden)
                .navigationDestination(for: String.self) { workoutId in
                    WorkoutDetailView(workoutId: workoutId)
                }
            }
        }
        .task {
            do {
                summaries = try appModel.workoutRepository.fetchRecentWorkouts()
            } catch {
                AppLog.ui.error("Failed to load workout history: \(error)")
            }
        }
    }

    private func formattedDuration(_ duration: TimeInterval) -> String {
        Duration.seconds(duration).formatted(.time(pattern: .minuteSecond))
    }

    private func detailText(for summary: WorkoutSummary) -> String {
        let volume = appModel.weightUnit.format(kilograms: summary.totalVolume)
        return "\(DurationFormat.clock(summary.duration)) \(volume)"
    }
}
