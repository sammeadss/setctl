//
//  RestorePurchasesButton.swift
//  SetctlModules
//
//  Created by Samuel Meads on 11/5/26.
//

import SetctlDesignSystem
import SwiftUI

/// Re-checks the user's Apple ID for an existing Pro purchase and shows the outcome under the button.
struct RestorePurchasesButton: View {
    @Environment(AppModel.self) private var appModel
    @State private var message: String?

    var body: some View {
        VStack(spacing: Spacing.xs) {
            Button("RESTORE PURCHASES") {
                Task { await restore() }
            }
            .font(Typography.label)
            .foregroundStyle(Palette.greenDim)

            if let message {
                Text(message)
                    .font(Typography.label)
                    .foregroundStyle(Palette.amber)
            }
        }
    }

    private func restore() async {
        do {
            message = try await appModel.restorePurchases() ? nil : "NO PURCHASES TO RESTORE."
        } catch {
            message = "RESTORE FAILED. CHECK YOUR CONNECTION."
        }
    }
}
