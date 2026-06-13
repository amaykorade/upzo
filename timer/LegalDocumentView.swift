import SwiftUI

enum LegalDocument {
    case privacyPolicy
    case termsOfService

    var title: String {
        switch self {
        case .privacyPolicy: return "Privacy Policy"
        case .termsOfService: return "Terms of Service"
        }
    }

    var publishedURL: URL? {
        switch self {
        case .privacyPolicy: return SettingsLinks.privacyPolicyURL
        case .termsOfService: return SettingsLinks.termsOfServiceURL
        }
    }

    var bodyText: String {
        switch self {
        case .privacyPolicy:
            return """
            This app helps you wake up using alarms and optional missions (shake, pushups, photo, object hunt, voice, math, steps, and more).

            **On your device**
            Alarm schedules, mission history, preferences, and insights are stored locally on your iPhone unless a feature clearly states otherwise.

            **Permissions**
            Notifications, camera, microphone, speech recognition, motion, and photos are used only for features you choose (alarms and missions).

            **Sign-in (optional)**
            If you use Sign in with Apple, we receive basic account information from Apple (such as a user ID and, if you allow it, your name or email) to operate sign-in on your device.

            **What we do not do**
            We do not sell your personal information. We do not use your data for cross-app advertising tracking.

            **Analytics**
            We use Microsoft Clarity to understand how the App is used (screens and taps) so we can improve it. Clarity does not receive your alarms, photos, or voice recordings.

            **Contact**
            Privacy questions: \(SettingsLinks.supportEmail)

            See the full Privacy Policy using the link below.
            """
        case .termsOfService:
            return """
            By using this app, you agree to use it responsibly and in compliance with applicable laws.

            **Alarms**
            The app is not a medical device. Alarms may fail due to device settings, battery, Focus modes, or other factors. Keep a backup wake-up plan for important events.

            **Missions**
            Complete missions safely. Do not use camera or motion missions while driving or in unsafe situations.

            **Account**
            Optional sign-in may be offered. Delete account in settings removes sign-in data on this device as described in the app.

            **Liability**
            The app is provided “as is” without warranty to the fullest extent permitted by law.

            **Contact**
            Questions: \(SettingsLinks.supportEmail)

            See the full Terms of Service using the link below.
            """
        }
    }
}

struct LegalDocumentView: View {
    @Environment(\.openURL) private var openURL

    let document: LegalDocument

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(LocalizedStringKey(document.bodyText))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let url = document.publishedURL {
                    Button {
                        openURL(url)
                    } label: {
                        Label("View full \(document.title) online", systemImage: "safari")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                } else {
                    Text("The summary above is provided in the app. Use Settings → Legal for the full document text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)
        }
        .timerScreenBackground()
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
