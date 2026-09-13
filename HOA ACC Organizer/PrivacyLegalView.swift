// Copyright © 2026 Christopher McMahon-Sutton.
// Licensed under the PolyForm Perimeter License 1.0.1.
// Author: Christopher McMahon-Sutton.
// Additional modification, documentation, and testing assistance:
// ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
// See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

import SwiftUI

/// Presents the privacy policy, copyright notice, source-code license, and support guidance from inside the app.
struct PrivacyLegalView: View {
    /// Dismisses the privacy/legal sheet when the user is finished reading it.
    @Environment(\.dismiss) private var dismiss

    /// The SwiftUI view hierarchy rendered by this screen.
    var body: some View {
        NavigationStack {
            List {
                Section("Privacy Policy") {
                    Text("Effective September 13, 2026")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    legalText(
                        "Local-first storage",
                        "HOA ACC Organizer stores its working database and managed attachments in the app's local container. The app does not include advertising or third-party analytics SDKs and does not use a developer-operated cloud backend."
                    )

                    legalText(
                        "HOA records",
                        "Depending on use, the app can contain property addresses, owner/resident contact information, violations, ACC applications, notes, dates, photographs, PDFs, neighbor acknowledgements, audit history, and account-role information. The HOA or organization using the app is responsible for the records it enters and shares."
                    )

                    legalText(
                        "Photos and camera",
                        "Camera and photo-library access is used only when a user chooses to document a violation or ACC application."
                    )

                    legalText(
                        "OCR and Apple Intelligence",
                        "ACC PDF recognition uses Apple Vision locally. On supported devices, Apple's on-device Foundation Models framework may help organize OCR text. If unavailable, the app uses its Vision/deterministic fallback. The app does not send ACC text to a developer-operated AI service."
                    )

                    legalText(
                        "Nearby sync",
                        "Compatible devices can exchange HOA records and attachments directly over the local network using Bonjour and Network.framework. Nearby sync does not use a developer-operated cloud database. Use it only with trusted devices and trusted local networks."
                    )

                    legalText(
                        "Exports and sharing",
                        "Backups, JSON exports, PDF reports, decision letters, and share-sheet items can contain HOA or personal information. After a user saves or shares a file to another destination, that destination's privacy and retention practices apply."
                    )

                    legalText(
                        "Third parties",
                        "The app does not automatically disclose HOA records to advertising networks, data brokers, or a developer-operated analytics service. If a user deliberately shares data with another app, service, or person, the HOA or user is responsible for selecting a recipient that provides appropriate protection for that information."
                    )

                    legalText(
                        "Retention and deletion",
                        "Local data remains until it is removed through available workflows, replaced/restored, or the app's local data is deleted. Exported files remain at their saved destinations until deleted there. Contact the responsible HOA administrator for correction/deletion requests involving HOA-controlled records."
                    )

                    legalText(
                        "Biometrics",
                        "Face ID/Touch ID authentication is handled by Apple. HOA ACC Organizer does not receive or store biometric templates."
                    )

                    legalText(
                        "Permissions",
                        "Camera, Photos, notifications, Face ID/Touch ID, and Local Network permissions can be changed in Apple system settings."
                    )
                }

                Section("Copyright & License") {
                    Text("Copyright © 2026 Christopher McMahon-Sutton.")

                    Text("Author: Christopher McMahon-Sutton")

                    Text("Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.")
                        .foregroundStyle(.secondary)

                    Text("Project-owned source code is source-available under the PolyForm Perimeter License 1.0.1. The license does not permit providing a competing product.")

                    if let privacyURL = configuredURL(
                        key: "HOAPrivacyPolicyURL"
                    ) {
                        Link(
                            "Privacy Policy Online",
                            destination: privacyURL
                        )
                    }

                    Link(
                        "PolyForm Perimeter License 1.0.1",
                        destination: URL(string: "https://polyformproject.org/licenses/perimeter/1.0.1")!
                    )

                    if let sourceURL = configuredURL(
                        key: "HOASourceCodeURL"
                    ) {
                        Link(
                            "Source Repository",
                            destination: sourceURL
                        )
                    }
                }

                Section("Support") {
                    Text("Developer: Christopher McMahon-Sutton. For support or privacy requests, use the Support URL listed for HOA ACC Organizer in the App Store. For HOA-controlled records, contact the organization's authorized administrator. Do not post private member data in a public issue.")

                    if let supportURL = configuredURL(
                        key: "HOASupportURL"
                    ) {
                        Link(
                            "Open Support Page",
                            destination: supportURL
                        )
                    }
                }
            }
            .navigationTitle("Privacy & Legal")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(
            minWidth: 640,
            idealWidth: 700,
            minHeight: 560,
            idealHeight: 680
        )
        #endif
    }

    /// Creates a labeled privacy-policy paragraph with consistent hierarchy and wrapping.
    @ViewBuilder
    private func legalText(
        _ title: String,
        _ body: String
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 6
        ) {
            Text(title)
                .font(.headline)

            Text(body)
                .foregroundStyle(.secondary)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
        .padding(.vertical, 4)
    }
    /// Returns a configured public legal/support URL from Info.plist when the value is nonblank and valid.
    private func configuredURL(
        key: String
    ) -> URL? {
        guard
            let raw = Bundle.main.object(
                forInfoDictionaryKey: key
            ) as? String,
            !raw.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
            let url = URL(
                string: raw
            )
        else {
            return nil
        }

        return url
    }

}
