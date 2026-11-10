//
//  HomeView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 7/23/26.
//

import SetctlData
import SetctlDesignSystem
import SwiftUI

public struct HomeView: View {
    @State private var isSessionActive = false
    @State private var isSettingsPresented = false
    @Environment(AppModel.self) private var appModel
    @State private var hasUnfinishedWorkout = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Palette.black.ignoresSafeArea()
                Button {
                    isSessionActive = true
                } label: {
                    PowerSymbol()
                        .fill(Palette.green)
                        .frame(width: 160, height: 160)
                        .overlay(alignment: .bottom) {
                            if hasUnfinishedWorkout {
                                Text("WORKOUT IN PROGRESS")
                                    .font(Typography.label)
                                    .foregroundStyle(Palette.greenDim)
                                    .fixedSize()
                                    .offset(y: Spacing.xl)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hasUnfinishedWorkout ? "Resume workout" : "Begin workout")
            }
            .toolbar {
                Button {
                    isSettingsPresented = true
                } label: {
                    Image(systemName: "gear")
                }
                .foregroundStyle(Palette.green)
                .accessibilityLabel("Settings")
            }
            .onAppear {
                // Re-checked on every appearance so RESUME shows after a session. This also closes stale unfinished
                // workouts as a side effect.
                hasUnfinishedWorkout = (try? appModel.workoutRepository.resolveUnfinishedWorkout()) != nil
            }
            .navigationDestination(isPresented: $isSessionActive) {
                ActiveSessionView()
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView()
            }
        }
    }
}

#Preview {
    HomeView()
        // swiftlint:disable:next force_try
        .environment(try! AppModel(database: .empty(), supabaseClient: SupabaseConfig.makeClient()))
}
