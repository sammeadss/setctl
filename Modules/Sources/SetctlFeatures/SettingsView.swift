//
//  SettingsView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/6/26.
//

import SetctlCore
import SetctlData
import SetctlDesignSystem
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKey.scanlinesEnabled) private var isScanLinesEnabled = true
    @AppStorage(StorageKey.hapticsEnabled) private var isHapticsEnabled = true
    @AppStorage(StorageKey.highContrastEnabled) private var isHighContrastEnabled = false
    @AppStorage(StorageKey.scanlineMotionEnabled) private var isScanlineMotionEnabled = false
    @State private var exportFile: ExportFile?
    @State private var exportFailed = false
    @State private var deletion = Deletion.idle
    @State private var isConfirmingDelete = false
    @State private var isManagingSubscription = false
    @State private var diagnosticsFiles: [URL] = []

    private enum Deletion {
        case idle, deleting, failed, deleted
    }

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

                        syncSection

                        exportSection

                        diagnosticsSection

                        accountSection
                    }
                    .padding(Spacing.lg)
                }
                // Rebuilt when the unit changes, because the CSV carries converted weights.
                .task(id: appModel.weightUnit) { prepareExport() }
                .task(id: appModel.weightUnit) { prepareExport() }
                .task { diagnosticsFiles = (try? DiagnosticsStore.standard().files()) ?? [] }
            }
            .toolbar {
                Button("DONE") { dismiss() }
                    .foregroundStyle(Palette.green)
            }
        }
        #if os(iOS)
        .manageSubscriptionsSheet(isPresented: $isManagingSubscription)
        #endif
    }

    private var unitsRow: some View {
        VStack(spacing: Spacing.xs) {
            Text("UNITS")
                .font(Typography.label)
                .foregroundStyle(Palette.greenDim)

            Picker(
                "Units",
                selection: Binding(
                    get: { appModel.weightUnit },
                    set: { appModel.setUnits($0) }
                )
            ) {
                ForEach(WeightUnit.allCases, id: \.self) { unit in
                    Text(unit.rawValue).tag(unit)
                }
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
            if deletion == .deleted {
                Text("ACCOUNT DELETED. WORKOUTS ON THIS DEVICE ARE UNCHANGED.")
                    .font(Typography.label)
                    .foregroundStyle(Palette.greenDim)
                    .multilineTextAlignment(.center)
            }
            AuthView()
        case .signedIn:
            signedInAccount
        }
    }

    private var signedInAccount: some View {
        VStack(spacing: Spacing.md) {
            Button("SIGN OUT") {
                Task { try? await appModel.authRepository.signOut() }
            }
            .font(Typography.body)
            .foregroundStyle(Palette.greenDim)

            Button("DELETE ACCOUNT") {
                isConfirmingDelete = true
            }
            .font(Typography.body)
            .foregroundStyle(Palette.red)
            .disabled(deletion == .deleting)

            if deletion == .deleting {
                Text("DELETING...")
                    .font(Typography.label)
                    .foregroundStyle(Palette.greenDim)
            } else if deletion == .failed {
                Text("DELETE FAILED. NOTHING WAS CHANGED.")
                    .font(Typography.label)
                    .foregroundStyle(Palette.amber)
            }
        }
        .onAppear { deletion = .idle }
        .confirmationDialog("Delete your account?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteMessage: String {
        let base = "This permanently deletes your account and synced workouts from our servers. "
            + "Workouts on this device stay."
        guard appModel.isPro else { return base }
        return base + " Your subscription is not cancelled; use MANAGE SUBSCRIPTION to cancel it."
    }

    private func deleteAccount() async {
        deletion = .deleting
        do {
            try await appModel.deleteAccount()
            deletion = .deleted
        } catch {
            deletion = .failed
        }
    }

    @ViewBuilder
    private var proSection: some View {
        if appModel.isPro {
            VStack(spacing: Spacing.xs) {
                Text("SETCTL PRO: ACTIVE")
                    .font(Typography.label)
                    .foregroundStyle(Palette.greenDim)
                #if os(iOS)
                    Button("MANAGE SUBSCRIPTION") {
                        isManagingSubscription = true
                    }
                    .font(Typography.label)
                    .foregroundStyle(Palette.green)
                #endif
            }
        } else if case .guest = appModel.authState {
            Text("SIGN IN TO UPGRADE TO PRO")
                .font(Typography.label)
                .foregroundStyle(Palette.greenDim)
        } else if let product = appModel.proProduct {
            // Nothing is offered until the StoreKit product has loaded.
            Button("UPGRADE TO PRO \(product.displayPrice)/MO") {
                Task { await appModel.purchasePro() }
            }
            .font(Typography.body)
            .foregroundStyle(Palette.green)
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        if let text = appModel.syncStatus.displayText {
            VStack(spacing: Spacing.xs) {
                Text(text)
                    .font(Typography.label)
                    .foregroundStyle(appModel.syncStatus.isWarning ? Palette.amber : Palette.greenDim)
                    .multilineTextAlignment(.center)

                if appModel.syncStatus.canSyncNow {
                    Button("SYNC NOW") {
                        Task { await appModel.requestSync() }
                    }
                    .font(Typography.body)
                    .foregroundStyle(Palette.green)
                }
            }
        }
    }

    @ViewBuilder
    private var exportSection: some View {
        if let exportFile {
            ShareLink(item: exportFile, preview: SharePreview("Setctl export")) {
                Text("EXPORT DATA")
            }
            .font(Typography.body)
            .foregroundStyle(Palette.green)
        } else if exportFailed {
            Text("EXPORT UNAVAILABLE")
                .font(Typography.label)
                .foregroundStyle(Palette.amber)
        }
    }

    @ViewBuilder
    private var diagnosticsSection: some View {
        if !diagnosticsFiles.isEmpty {
            ShareLink(items: diagnosticsFiles) {
                Text("EXPORT DIAGNOSTICS (\(diagnosticsFiles.count))")
            }
            .font(Typography.label)
            .foregroundStyle(Palette.greenDim)
        }
    }

    private func prepareExport() {
        do {
            exportFile = try ExportFile(csv: appModel.exportCSV())
            exportFailed = false
        } catch {
            exportFile = nil
            exportFailed = true
        }
    }
}

#Preview {
    SettingsView()
        // swiftlint:disable:next force_try
        .environment(try! AppModel(database: .empty(), supabaseClient: SupabaseConfig.makeClient()))
}
