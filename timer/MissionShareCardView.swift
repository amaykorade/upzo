#if os(iOS)
import SwiftUI

struct MissionShareSnapshot: Equatable {
    let missionTitle: String
    let celebrationMessage: String
    let wakeUpTime: String
    let wakeUpDate: String
    var huntTargetName: String?
    var huntTargetSystemImage: String?

    var isObjectHuntShare: Bool {
        huntTargetName != nil && huntTargetSystemImage != nil
    }
}

/// 9:16 share banner — matches the post-mission success screen.
struct MissionShareCardView: View {
    static let exportSize = CGSize(width: 1080, height: 1920)

    let snapshot: MissionShareSnapshot

    var body: some View {
        ZStack {
            Color.black

            RadialGradient(
                colors: [
                    AppTheme.sunAccent.opacity(0.34),
                    AppTheme.sunAccent.opacity(0.08),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 40,
                endRadius: 780
            )

            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.35),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(spacing: 0) {
                Spacer(minLength: 100)

                AppLogoView(size: 168, style: .appIcon)
                    .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
                    .shadow(color: AppTheme.sunAccent.opacity(0.55), radius: 40, y: 16)

                Text("You did it!")
                    .font(.system(size: 92, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.top, 52)

                VStack(spacing: 14) {
                    Text("with")
                        .font(.system(size: 40, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))

                    Text(AppBrand.name)
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: AppTheme.sunAccent.opacity(0.85), radius: 16, y: 5)
                        .padding(.horizontal, 52)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(AppTheme.sunAccent.opacity(0.26))
                                .overlay(
                                    Capsule()
                                        .strokeBorder(AppTheme.sunAccent.opacity(0.72), lineWidth: 2.5)
                                )
                        )
                }
                .padding(.top, 32)

                wakeTimeBadge
                    .padding(.top, 48)

                cringeCard
                    .padding(.horizontal, 64)
                    .padding(.top, 52)

                MissionShareMissionLabel(snapshot: snapshot, style: .export)
                    .padding(.top, 44)

                Spacer(minLength: 100)

                Text(snapshot.wakeUpDate)
                    .font(.system(size: 26, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.38))
                    .padding(.bottom, 72)
            }
        }
        .frame(width: Self.exportSize.width, height: Self.exportSize.height)
    }

    private var wakeTimeBadge: some View {
        HStack(spacing: 16) {
            Image(systemName: "sunrise.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(AppTheme.sunAccent)

            VStack(alignment: .leading, spacing: 4) {
                Text("WOKE UP AT")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .tracking(2)

                Text(snapshot.wakeUpTime)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.14), lineWidth: 1.5)
                )
        )
    }

    private var cringeCard: some View {
        VStack(spacing: 0) {
            Text("“")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sunAccent.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: 12)

            Text(snapshot.celebrationMessage)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(10)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)

            Text("”")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sunAccent.opacity(0.85))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .offset(y: -12)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 32)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(AppTheme.sunAccent.opacity(0.35), lineWidth: 1.5)
                )
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(AppTheme.sunAccent)
                .frame(width: 8)
                .padding(.vertical, 24)
                .padding(.leading, 4)
        }
    }

}

struct MissionShareMissionLabel: View {
    enum Style {
        case screen
        case export
    }

    let snapshot: MissionShareSnapshot
    var style: Style = .screen

    var body: some View {
        Group {
            if snapshot.isObjectHuntShare,
               let targetName = snapshot.huntTargetName,
               let targetIcon = snapshot.huntTargetSystemImage {
                objectHuntRow(targetName: targetName, targetIcon: targetIcon)
            } else {
                standardMissionRow
            }
        }
        .foregroundStyle(AppTheme.sunAccent)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(
            Capsule()
                .fill(AppTheme.sunAccent.opacity(0.14))
                .overlay(
                    Capsule()
                        .strokeBorder(AppTheme.sunAccent.opacity(0.45), lineWidth: strokeWidth)
                )
        )
    }

    private var standardMissionRow: some View {
        HStack(spacing: iconSpacing) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: iconSize, weight: .semibold))
            Text(snapshot.missionTitle.uppercased())
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .tracking(style == .export ? 2.5 : 2)
        }
    }

    private func objectHuntRow(targetName: String, targetIcon: String) -> some View {
        HStack(spacing: iconSpacing) {
            Text("Object hunt")
                .font(.system(size: titleSize, weight: .bold, design: .rounded))

            Text("=")
                .font(.system(size: equalsSize, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.sunAccent.opacity(0.75))

            Image(systemName: targetIcon)
                .font(.system(size: objectIconSize, weight: .semibold))

            Text(targetName)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
        }
    }

    private var iconSize: CGFloat { style == .export ? 28 : 14 }
    private var objectIconSize: CGFloat { style == .export ? 32 : 16 }
    private var titleSize: CGFloat { style == .export ? 26 : 11 }
    private var equalsSize: CGFloat { style == .export ? 30 : 14 }
    private var iconSpacing: CGFloat { style == .export ? 12 : 6 }
    private var horizontalPadding: CGFloat { style == .export ? 28 : 12 }
    private var verticalPadding: CGFloat { style == .export ? 14 : 6 }
    private var strokeWidth: CGFloat { style == .export ? 1.5 : 1 }
}

enum MissionShareFormatting {
    static func snapshot(
        missionTitle: String,
        celebrationMessage: String,
        completedAt: Date = Date(),
        huntTarget: HuntObject? = nil
    ) -> MissionShareSnapshot {
        let calendar = Calendar.current
        let (hour, minute) = Alarm.pickerTime(from: completedAt)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEEE, MMM d"
        dateFormatter.locale = Locale.current

        return MissionShareSnapshot(
            missionTitle: missionTitle,
            celebrationMessage: celebrationMessage,
            wakeUpTime: Alarm.formattedTime(hour: hour, minute: minute),
            wakeUpDate: dateFormatter.string(from: completedAt),
            huntTargetName: huntTarget?.displayName,
            huntTargetSystemImage: huntTarget?.systemImage
        )
    }
}
#endif
