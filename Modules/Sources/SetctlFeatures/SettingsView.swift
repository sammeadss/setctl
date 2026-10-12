//
//  SettingsView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/6/26.
//

import SetctlData
import SetctlDesignSystem
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKey.scanlinesEnabled) private var isScanLinesEnabled = true
    @AppStorage(StorageKey.hapticsEnabled) private var isHapticsEnabled = true
    @AppStorage(StorageKey.highContrastEnabled) private var isHighContrastEnabled = false
    @AppStorage(StorageKey.scanlineMotionEnabled) private var isScanlineMotionEnabled = false

    var body: some View {
        NavigationStack {
            ZStack {
                Palette.black.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.lg) {
                        Text("SETTINGS")
                            .font(Typography.title)
                            .foregroundStyle(Palette.green)

                        unitsRow

                        scanlinesRow

                        scanlineMotionRow

                        hapticsRow

                        highContrastRow

                        proSection

                        accountSection
                    }
                    .padding(Spacing.lg)
                }
            }
            .toolbar {
                Button("DONE") { dismiss() }
                    .foregroundStyle(Palette.green)
            }
        }
    }

    private var unitsRow: some View {
        VStack(spacing: Spacing.xs) {
            Text("UNITS")
                .font(Typography.label)
                .foregroundStyle(Palette.greenDim)

            Picker(
                "Units",
                selection: Binding(
                    get: { appModel.profile.units },
                    set: { appModel.setUnits($0) }
                )
            ) {
                Text("kg").tag("kg")
                Text("lb").tag("lb")
            }
            .pickerStyle(.segmented)
        }
    }

    private var scanlinesRow: some View {
        Toggle("SCANLINES", isOn: $isScanLinesEnabled)
            .font(Typography.label)
            .foregroundStyle(Palette.greenDim)
            .tint(Palette.green)
    }

    private var scanlineMotionRow: some View {
        Toggle("SCANLINE MOTION", isOn: $isScanlineMotionEnabled)
            .font(Typography.label)
            .foregroundStyle(Palette.greenDim)
            .tint(Palette.green)
    }

    private var hapticsRow: some View {
        Toggle("HAPTICS", isOn: $isHapticsEnabled)
            .font(Typography.label)
            .foregroundStyle(Palette.greenDim)
            .tint(Palette.green)
    }

    private var highContrastRow: some View {
        Toggle("HIGH CONTRAST", isOn: $isHighContrastEnabled)
            .font(Typography.label)
            .foregroundStyle(Palette.greenDim)
            .tint(Palette.green)
    }

    @ViewBuilder
    private var accountSection: some View {
        switch appModel.authState {
        case .guest:
            AuthView()
        case .signedIn:
            Button("SIGN OUT") {
                Task { try? await appModel.authRepository.signOut() }
            }
            .font(Typography.body)
            .foregroundStyle(Palette.greenDim)
        }
    }

    @ViewBuilder
    private var proSection: some View {
        if appModel.isPro {
            Text("SETCTL PRO: ACTIVE")
                .font(Typography.label)
                .foregroundStyle(Palette.greenDim)
        } else if let product = appModel.proProduct {
            Button("UPGRADE TO PRO \(product.displayPrice)/MO") {
                Task { await appModel.purchasePro() }
            }
            .font(Typography.body)
            .foregroundStyle(Palette.green)
        }
    }
}

#Preview {
    SettingsView()
        // swiftlint:disable:next force_try
        .environment(try! AppModel(database: .empty(), supabaseClient: SupabaseConfig.makeClient()))
}
