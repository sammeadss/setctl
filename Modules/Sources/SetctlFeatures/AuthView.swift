//
//  AuthView.swift
//  SetctlModules
//
//  Created by Samuel Meads on 10/5/26.
//

import SetctlData
import SetctlDesignSystem
import SwiftUI

public struct AuthView: View {
    @Environment(AppModel.self) private var appModel

    private enum Step {
        case email
        case password
    }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    public init() {}

    public var body: some View {
        ZStack {
            Palette.black.ignoresSafeArea()

            VStack(spacing: Spacing.lg) {
                Text("ACCESS")
                    .font(Typography.title)
                    .foregroundStyle(Palette.green)

                Text("TRAIN. LOG. REPEAT.")
                    .font(Typography.label)
                    .foregroundStyle(Palette.greenDim)

                if step == .email {
                    field(text: $email, placeholder: "email", isSecure: false)

                    Button("CONTINUE") {
                        step = .password
                    }
                    .font(Typography.body)
                    .foregroundStyle(Palette.greenDim)
                } else {
                    field(text: $password, placeholder: "password", isSecure: true)

                    Button("ENTER") {
                        Task { await submit() }
                    }
                    .font(Typography.body)
                    .foregroundStyle(Palette.green)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(Typography.label)
                        .foregroundStyle(Palette.green)
                }
            }
            .padding(Spacing.lg)
        }
        .onAppear {
            isFieldFocused = true
        }
        .onChange(of: step) {
            isFieldFocused = true
        }
    }

    private func field(text: Binding<String>, placeholder: String, isSecure: Bool) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if isSecure {
                SecureField(placeholder, text: text)
                    .focused($isFieldFocused)
                    .font(Typography.body)
                    .foregroundStyle(Palette.green)
                    .tint(Palette.green)
            } else {
                TextField(placeholder, text: text)
                #if os(iOS)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                #endif
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    .font(Typography.body)
                    .foregroundStyle(Palette.green)
                    .tint(Palette.green)
            }

            Rectangle()
                .fill(isFieldFocused ? Palette.green : Palette.greenFaint)
                .frame(height: 1)
        }
    }

    /// Signs in, and if that fails tries to sign up, so one form serves both. A failure shows the sign-up error.
    private func submit() async {
        errorMessage = nil
        do {
            try await appModel.authRepository.signIn(email: email, password: password)
        } catch {
            do {
                try await appModel.authRepository.signUp(email: email, password: password)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    AuthView()
        // swiftlint:disable:next force_try
        .environment(try! AppModel(database: .empty(), supabaseClient: SupabaseConfig.makeClient()))
}
