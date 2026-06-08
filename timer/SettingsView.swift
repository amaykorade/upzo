import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Neutral label for Settings list rows (no sun/accent tint on icon or title).
private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsView: View {
#if os(iOS)
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var accountStore: AccountStore
    @Environment(\.openURL) private var openURL
    @State private var showAlarmSettingsSheet = false
    @State private var showNotificationSettingsSheet = false
    @State private var showAccountSettingsSheet = false
    @ObservedObject private var onboardingStore = OnboardingStore.shared
    @State private var showOnboardingRetake = false
#endif

    @AppStorage("settings.prefersDarkMode") private var prefersDarkMode = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                TimerScreenTitle(title: "Settings")

                Form {
                    alarmSection
                    preferencesSection
                    supportSection
                    legalSection
                    accountSection
                }
#if os(iOS)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .symbolRenderingMode(.monochrome)
                .contentMargins(.horizontal, 0, for: .scrollContent)
#endif
            }
            .timerTabScreenInsets()
            .timerScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
#if os(iOS)
            .sheet(isPresented: $showAlarmSettingsSheet) {
                AlarmSettingsSheet()
                    .environmentObject(AlarmAppSettingsStore.shared)
                    .environmentObject(alarmStore)
            }
            .sheet(isPresented: $showNotificationSettingsSheet) {
                NotificationSettingsSheet()
                    .environmentObject(NotificationPreferencesStore.shared)
                    .environmentObject(alarmStore)
            }
            .sheet(isPresented: $showAccountSettingsSheet) {
                AccountSettingsSheet()
                    .environmentObject(accountStore)
                    .environmentObject(SubscriptionStore.shared)
            }
            .fullScreenCover(isPresented: $showOnboardingRetake) {
                OnboardingFlowView {
                    showOnboardingRetake = false
                    onboardingStore.markCompleted()
                }
                .environmentObject(alarmStore)
                .environmentObject(AlarmAppSettingsStore.shared)
            }
#endif
        }
        .tint(.primary)
    }

    // MARK: - Alarm

    private var alarmSection: some View {
        Section {
#if os(iOS)
            Button {
                showAlarmSettingsSheet = true
            } label: {
                SettingsRowLabel(title: "Alarm settings", systemImage: "alarm.fill")
            }

            NavigationLink {
                AlarmTroubleshootingView()
            } label: {
                SettingsRowLabel(title: "Alarm not working", systemImage: "questionmark.circle")
            }

            Button {
                openURL(SettingsLinks.reportBug)
            } label: {
                SettingsRowLabel(title: "Report a bug", systemImage: "ladybug")
            }
#else
            Label("Alarm settings", systemImage: "alarm.fill")
                .foregroundStyle(.secondary)
#endif
        } header: {
            Text("Alarm")
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        Section {
#if os(iOS)
            Button {
                showNotificationSettingsSheet = true
            } label: {
                SettingsRowLabel(title: "Notifications", systemImage: "bell.badge")
            }
#endif

            NavigationLink {
                LanguageSettingsView()
            } label: {
                HStack {
                    SettingsRowLabel(title: "Language", systemImage: "globe")
                    Spacer()
                    Text("English")
                        .foregroundStyle(.secondary)
                }
            }

            Toggle(isOn: $prefersDarkMode) {
                SettingsRowLabel(title: "Dark mode", systemImage: "moon.fill")
            }
            .tint(AppTheme.toggleTint)

            Button {
                onboardingStore.resetForRetake()
                showOnboardingRetake = true
            } label: {
                SettingsRowLabel(title: "Retake wake-up quiz", systemImage: "list.clipboard")
            }
        } header: {
            Text("Preferences")
        }
    }

    // MARK: - Support

    private var supportSection: some View {
        Section {
#if os(iOS)
            Button {
                openURL(SettingsLinks.requestFeature)
            } label: {
                SettingsRowLabel(title: "Request a feature", systemImage: "lightbulb")
            }

            Button {
                openURL(SettingsLinks.contactSupport)
            } label: {
                SettingsRowLabel(title: "Contact support", systemImage: "envelope")
            }

            if let url = SettingsLinks.writeReviewURL {
                Button {
                    openURL(url)
                } label: {
                    SettingsRowLabel(title: "Leave a review", systemImage: "star")
                }
            }
#else
            Label("Request a feature", systemImage: "lightbulb")
                .foregroundStyle(.secondary)
            Label("Contact support", systemImage: "envelope")
                .foregroundStyle(.secondary)
#endif
        } header: {
            Text("Support")
        }
    }

    // MARK: - Legal

    private var legalSection: some View {
        Section {
            NavigationLink {
                LegalDocumentView(document: .privacyPolicy)
            } label: {
                SettingsRowLabel(title: "Privacy policy", systemImage: "hand.raised")
            }

            NavigationLink {
                LegalDocumentView(document: .termsOfService)
            } label: {
                SettingsRowLabel(title: "Terms of service", systemImage: "doc.text")
            }
        } header: {
            Text("Legal")
        }
    }

    // MARK: - Account

    private var accountSettingsRowLabel: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text("Account settings")
                    .foregroundStyle(.primary)
                Text(accountStore.signedInSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private var accountSection: some View {
        Section {
            if accountStore.isSignedIn {
                Button {
                    showAccountSettingsSheet = true
                } label: {
                    accountSettingsRowLabel
                }
            } else {
                AccountSignInSection()
                Button {
                    showAccountSettingsSheet = true
                } label: {
                    SettingsRowLabel(title: "Subscription & more", systemImage: "creditcard")
                }
            }
        } header: {
            Text("Account")
        } footer: {
            if !accountStore.isSignedIn {
                Text("Sign in with Apple is required during setup to use the app.")
            }
        }
    }
}

#Preview {
#if os(iOS)
    SettingsView()
        .environmentObject(AlarmStore.mock())
        .environmentObject(AlarmAppSettingsStore.shared)
        .environmentObject(NotificationPreferencesStore.shared)
        .environmentObject(AccountStore.shared)
#else
    SettingsView()
#endif
}
