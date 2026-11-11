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

/// The app's entry point and composition root: builds the database and Supabase client, then shows the tabs.
@main
struct SetctlApp: App {
    @State private var appModel: AppModel
    @State private var selectedTab = Tab.home
    @Environment(\.scenePhase) private var scenePhase

    private enum Tab {
        case settings, home, history
    }

    private let diagnostics = DiagnosticsCollector.startStandard()

    init() {
        do {
            let database = try AppDatabase.makeShared()
            let supabaseClient = SupabaseConfig.makeClient()
            _appModel = try State(initialValue: AppModel(database: database, supabaseClient: supabaseClient))
        } catch {
            // Without local database, app cannot log workouts; nothing to fall back to.
            fatalError("Failed to initialize the app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
                    .tag(Tab.settings)

                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house")
                    }
                    .tag(Tab.home)

                HistoryView()
                    .tabItem {
                        Label("History", systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    }
                    .tag(Tab.history)
            }
            .tint(Palette.green)
            .environment(appModel)
            .onChange(of: scenePhase) { _, phase in
                // Sync on returning to the foreground; the app doesn't pull while it stays open.
                if phase == .active {
                    Task { await appModel.appDidBecomeActive() }
                }
            }
        }
    }
}
