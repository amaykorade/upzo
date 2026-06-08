#if os(iOS)
import UIKit
#endif
import SwiftUI

struct AlarmTroubleshootingView: View {
#if os(iOS)
    @Environment(\.openURL) private var openURL
#endif

    var body: some View {
        List {
            Section {
                troubleshootingRow(
                    title: "Check alarm is on",
                    detail: "Open the Alarms tab and make sure your wake-up is enabled."
                )
                troubleshootingRow(
                    title: "Allow notifications",
                    detail: "Go to Preferences → Notifications and enable permission."
                )
                troubleshootingRow(
                    title: "Enable system alarms",
                    detail: "In Alarm settings, turn on system alarms for Clock-style ringing."
                )
                troubleshootingRow(
                    title: "Disable Focus / Silent",
                    detail: "Focus modes or Silent switch can limit how alerts appear. Check iOS Settings."
                )
                troubleshootingRow(
                    title: "Keep app updated",
                    detail: "Force-quit and reopen the app after changing permissions."
                )
            }

#if os(iOS)
            Section {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label {
                        Text("Open iOS Settings")
                    } icon: {
                        Image(systemName: "gear")
                            .foregroundStyle(.secondary)
                    }
                }
            }
#endif
        }
        .navigationTitle("Alarm not working")
        .navigationBarTitleDisplayMode(.inline)
        .tint(.primary)
    }

    private func troubleshootingRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
