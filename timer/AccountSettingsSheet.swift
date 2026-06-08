#if os(iOS)
import SwiftUI
import UIKit

struct AccountSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var accountStore: AccountStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore

    @State private var showLogoutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var showCopiedConfirmation = false
    @State private var showPaywallPreview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TimerScreenTitle(title: "Account")

                    if accountStore.isSignedIn {
                        signedInSection
                    } else {
                        signInRelocatedNotice
                    }
                    subscriptionSection
                    accountSection
                    dangerZoneSection
                }
                .timerTabScreenInsets()
                .padding(.bottom, 24)
            }
            .timerScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Log out?", isPresented: $showLogoutConfirmation) {
                Button("Log out", role: .destructive) {
                    accountStore.logout()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to sign in again on this device.")
            }
            .alert("Delete account?", isPresented: $showDeleteAccountConfirmation) {
                Button("Delete account", role: .destructive) {
                    accountStore.deleteAccount()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This deletes your sign-in session and account data stored on this iPhone. It does not delete your alarms. We do not operate a cloud account yet—nothing is removed from a server.")
            }
            .overlay(alignment: .bottom) {
                if showCopiedConfirmation {
                    Text("Account ID copied")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(AppTheme.cardFill, in: Capsule())
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showCopiedConfirmation)
            .tint(.primary)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .fullScreenCover(isPresented: $showPaywallPreview) {
            SubscriptionPaywallView {
                showPaywallPreview = false
            }
            .environmentObject(subscriptionStore)
        }
    }

    // MARK: - Sections

    private var signInRelocatedNotice: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Sign in")
            VStack(alignment: .leading, spacing: 6) {
                Text("Use Sign in with Apple on the main Settings screen (close this sheet first).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .timerCardBackground()
        }
    }

    private var signedInSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Signed in")

            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 52, height: 52)
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(signedInPrimaryLine)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    if let secondary = signedInSecondaryLine {
                        Text(secondary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }

                    Text("Signed in with \(accountStore.authProvider.displayName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
            .timerCardBackground()
        }
    }

    private var signedInPrimaryLine: String {
        if let name = accountStore.displayName, !name.isEmpty { return name }
        if let email = accountStore.email, !email.isEmpty { return email }
        return "Signed in"
    }

    private var signedInSecondaryLine: String? {
        guard let name = accountStore.displayName, !name.isEmpty,
              let email = accountStore.email, !email.isEmpty,
              email.caseInsensitiveCompare(name) != .orderedSame
        else { return nil }
        return email
    }

    private var subscriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Subscription")

            Text(
                subscriptionStore.hasActiveSubscription
                    ? "Apple reports an active subscription on this device, so the app opens without the paywall."
                    : "No active subscription on this device — the paywall appears after sign-in."
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            SubscriptionPlansCard()
                .padding(14)
                .timerCardBackground()

            if subscriptionStore.hasActiveSubscription {
                Button {
                    showPaywallPreview = true
                } label: {
                    Label("Preview subscription screen", systemImage: "creditcard")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 14)
                        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button {
                Task { await subscriptionStore.refresh() }
            } label: {
                Label("Refresh subscription status", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Account")

            VStack(spacing: 0) {
                accountActionRow(
                    title: "Copy account ID",
                    subtitle: accountStore.accountIDShort,
                    icon: "doc.on.doc",
                    role: .normal,
                    showsDisclosure: false,
                    trailingLabel: "Copy"
                ) {
                    copyAccountID()
                }

                rowDivider

                accountActionRow(
                    title: "Log out",
                    icon: "rectangle.portrait.and.arrow.right",
                    role: .normal,
                    showsDisclosure: false
                ) {
                    if accountStore.isSignedIn {
                        showLogoutConfirmation = true
                    } else {
                        accountStore.logout()
                    }
                }
            }
            .timerCardBackground()
        }
    }

    private var dangerZoneSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Danger zone")

            accountActionRow(
                title: "Delete account",
                icon: "trash",
                role: .destructive,
                showsDisclosure: false
            ) {
                showDeleteAccountConfirmation = true
            }
            .timerCardBackground()
        }
    }

    // MARK: - Components

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.sectionHeaderFont)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private var rowDivider: some View {
        Divider().padding(.leading, 52)
    }

    private enum AccountActionRole {
        case normal
        case destructive
    }

    private func accountActionRow(
        title: String,
        subtitle: String? = nil,
        icon: String,
        role: AccountActionRole,
        showsDisclosure: Bool = true,
        trailingLabel: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(role == .destructive ? Color.red : .secondary)
                    .frame(width: 28, alignment: .center)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(role == .destructive ? Color.red : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let trailingLabel {
                    Text(trailingLabel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                } else if showsDisclosure {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func copyAccountID() {
        accountStore.copyAccountIDToPasteboard()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        showCopiedConfirmation = true
        Task {
            try? await Task.sleep(for: .seconds(1.6))
            showCopiedConfirmation = false
        }
    }

}
#endif
