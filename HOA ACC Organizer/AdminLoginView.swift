// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Authenticates provisioned application accounts and offers biometric login after successful password authentication.
struct AdminLoginView: View {
    /// The shared application model used to read app state and perform workflow actions.
    @EnvironmentObject var model: AppModel
    /// The SwiftUI dismissal action for closing the current presentation.
    @Environment(\.dismiss) private var dismiss

    /// The account username associated with this value.
    @State private var username = ""
    /// Transient view state used to track password while this screen is active.
    @State private var password = ""
    /// Transient view state used to track error message while this screen is active.
    @State private var errorMessage = ""
    /// Transient view state used to track is authenticating while this screen is active.
    @State private var isAuthenticating = false

    /// The SwiftUI view hierarchy rendered by this view.
    var body: some View {
        NavigationStack {
            Group {
                #if os(macOS)
                macLoginContent
                #else
                mobileLoginContent
                #endif
            }
            .navigationTitle("Account Login")
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityIdentifier(
                        "admin.cancel"
                    )
                }

                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Login") {
                        submit()
                    }
                    .accessibilityIdentifier(
                        "admin.login"
                    )
                    .disabled(
                        username
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty ||
                        password.isEmpty
                    )
                }
            }
        }
        #if os(macOS)
        .frame(
            width: 640,
            height: 470
        )
        #endif
    }

    #if os(iOS)
    /// Standard form presentation used by iPhone and iPad.
    private var mobileLoginContent: some View {
        Form {
            Section("Account Login") {
                TextField(
                    "Username",
                    text: $username
                )
                .textContentType(.username)
                .loginInputBehavior()
                .accessibilityIdentifier(
                    "admin.username"
                )

                SecureField(
                    "Password",
                    text: $password
                )
                .textContentType(.password)
                .loginInputBehavior()
                .accessibilityIdentifier(
                    "admin.password"
                )
            }

            if model.biometricLoginAvailable {
                Section {
                    biometricButton
                } footer: {
                    biometricExplanation
                }
            }

            if !errorMessage.isEmpty {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }

            Section {
                buildLabel
            }
        }
    }
    #endif

    #if os(macOS)
    /// Bounded macOS layout that avoids Form label-column clipping in sheets.
    private var macLoginContent: some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 18
            ) {
                GroupBox("Credentials") {
                    VStack(spacing: 14) {
                        macLoginRow(
                            title: "Username"
                        ) {
                            TextField(
                                "Username",
                                text: $username
                            )
                            .textContentType(.username)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier(
                                "admin.username"
                            )
                        }

                        macLoginRow(
                            title: "Password"
                        ) {
                            SecureField(
                                "Password",
                                text: $password
                            )
                            .textContentType(.password)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier(
                                "admin.password"
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }

                if model.biometricLoginAvailable {
                    GroupBox("Biometric Login") {
                        VStack(
                            alignment: .leading,
                            spacing: 10
                        ) {
                            biometricButton
                            biometricExplanation
                        }
                        .padding(.vertical, 6)
                    }
                }

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                        .frame(
                            maxWidth: .infinity,
                            alignment: .leading
                        )
                        .padding(12)
                        .background(
                            RoundedRectangle(
                                cornerRadius: 10,
                                style: .continuous
                            )
                            .fill(
                                Color.red.opacity(0.08)
                            )
                        )
                }

                buildLabel
            }
            .padding(24)
            .frame(
                maxWidth: 590,
                alignment: .leading
            )
            .frame(
                maxWidth: .infinity,
                alignment: .top
            )
        }
    }

    /// Provides a stable label column for macOS account fields.
    private func macLoginRow<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(
            alignment: .firstTextBaseline,
            spacing: 16
        ) {
            Text(title)
                .frame(
                    width: 92,
                    alignment: .trailing
                )
                .foregroundStyle(.secondary)

            content()
                .frame(
                    maxWidth: .infinity
                )
        }
    }
    #endif

    /// Face ID / Touch ID control shared by the platform-specific layouts.
    private var biometricButton: some View {
        Button {
            biometricLogin()
        } label: {
            Label(
                "Use Face ID / Touch ID",
                systemImage: "faceid"
            )
        }
        .disabled(isAuthenticating)
    }

    /// Explains when biometric account unlock becomes available.
    private var biometricExplanation: some View {
        Text(
            "Biometric login becomes available on this device after a successful password login."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(
            horizontal: false,
            vertical: true
        )
    }

    /// Displays the running version and build number.
    private var buildLabel: some View {
        Text(
            "Build \(buildDescription)"
        )
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    /// The app version/build string shown on the account-login screen for support diagnostics.
    private var buildDescription: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String
            ?? "?"

        let build =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleVersion"
            ) as? String
            ?? "?"

        return "\(version) (\(build))"
    }

    /// Authenticates the typed username and password.
    private func submit() {
        errorMessage = ""

        do {
            try model.loginAccount(
                username:
                    username.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ),
                password: password
            )

            dismiss()
        } catch {
            errorMessage =
                error.localizedDescription
        }
    }

    /// Unlocks the account saved behind Face ID or Touch ID.
    private func biometricLogin() {
        isAuthenticating = true
        errorMessage = ""

        Task {
            do {
                try await model.loginWithBiometrics()
                dismiss()
            } catch {
                errorMessage =
                    error.localizedDescription
            }

            isAuthenticating = false
        }
    }
}


/// Adds HOA ACC Organizer behavior to `View`.
private extension View {
    @ViewBuilder
    /// Applies iOS-only keyboard behavior without changing macOS field semantics.
    func loginInputBehavior() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
        #else
        self
        #endif
    }
}
