//
//  SetctlApp.swift
//  Setctl
//
//  Created by Samuel Meads on 6/19/26.
//

import SetctlData
import SetctlDesignSystem
import SetctlFeatures
import Supabase
import SwiftUI
import UIKit

/// The app's entry point and composition root: builds the database and Supabase client, then shows the boot animation
/// before the tabs.
@main
struct SetctlApp: App {
    @State private var appModel: AppModel
    @State private var hasBooted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let database = try AppDatabase.makeShared()
            let supabaseClient = SupabaseConfig.makeClient()
            _appModel = try State(initialValue: AppModel(database: database, supabaseClient: supabaseClient))
            _hasBooted = State(initialValue: UIAccessibility.isReduceMotionEnabled)
        } catch {
            // Without local database, app cannot log workouts; nothing to fall back to.
            fatalError("Failed to initialize the app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            // Reduce Motion skips the boot animation.
            if hasBooted || reduceMotion {
                TabView {
                    HomeView()
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }

                    HistoryView()
                        .tabItem {
                            Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                        }
                }
                .tint(Palette.green)
                .environment(appModel)
                .onChange(of: scenePhase) { _, phase in
                    // Sync on returning to the foreground; the app doesn't pull while it stays open.
                    if phase == .active {
                        Task { await appModel.appDidBecomeActive() }
                    }
                }
            } else {
                BootView {
                    hasBooted = true
                }
            }
        }
    }
}
