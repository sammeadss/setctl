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
    @Environment(AppModel.self) private var appModel
    @State private var hasUnfinishedWorkout = false
    @AppStorage(StorageKey.hapticsEnabled) private var isHapticsEnabled = true

    private var syncLight: (mode: StatusLight.Mode, color: Color) {
        switch appModel.syncStatus {
        case .syncing: (.blinking, Palette.amber)
        case .synced: (.on, Palette.green)
        case .failed: (.on, Palette.amber)
        case .wrongAccount: (.on, Palette.red)
        case .off, .idle: (.off, Palette.red)
        }
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Palette.black.ignoresSafeArea()
                CodeRainView(opacity: 0.25)
                    .ignoresSafeArea()
                Button {
                    if isHapticsEnabled {
                        HapticEngine.shared.playBegin()
                    }
                    isSessionActive = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Palette.black)
                            .padding(7)
                        PowerSymbol(weight: 0.05)
                            .fill(Palette.green)
                    }
                    .frame(width: 176, height: 176)
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .overlay(alignment: .trailing) {
                    VStack(spacing: Spacing.sm) {
                        StatusLight(mode: hasUnfinishedWorkout ? .on : .off, color: Palette.amber)
                        StatusLight(mode: syncLight.mode, color: syncLight.color)
                    }
                    .padding(Spacing.xs)
                    .background(Palette.black, in: Capsule())
                    .offset(x: Spacing.xl)
                }
                .accessibilityLabel(hasUnfinishedWorkout ? "Resume workout" : "Begin workout")
            }
            .onAppear {
                // Re-checked on every appearance so RESUME shows after a session. This also closes stale unfinished
                // workouts as a side effect.
                hasUnfinishedWorkout = (try? appModel.workoutRepository.resolveUnfinishedWorkout()) != nil
            }
            .navigationDestination(isPresented: $isSessionActive) {
                ActiveSessionView()
            }
        }
    }
}

#Preview {
    HomeView()
        // swiftlint:disable:next force_try
        .environment(try! AppModel(database: .empty(), supabaseClient: SupabaseConfig.makeClient()))
}
