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
            fatalError("Failed to initialize the app: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
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
