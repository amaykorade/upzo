import SwiftUI

/// Shared alarm list row metrics so Home and Alarms stay visually consistent.
enum AlarmRowStyle {
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 12
    static let rowSpacing: CGFloat = 12
    static let contentSpacing: CGFloat = 6

    static let nameFont: Font = .subheadline.weight(.semibold)
    static let timeFont: Font = .system(size: 28, weight: .semibold, design: .rounded)
    static let metaFont: Font = .caption.weight(.medium)
    static let metaIconFont: Font = .caption.weight(.semibold)
}

/// Schedule · mission icon · mission name (Alarms tab and Home “Next wake up”).
struct AlarmRowMetaLine: View {
    let alarm: Alarm
    var enabled: Bool = true

    var body: some View {
        HStack(spacing: 6) {
            Text(alarm.listScheduleLabel)
                .lineLimit(1)
            Text("·")
                .foregroundStyle(Color.primary.opacity(0.25))
            Image(systemName: alarm.missionType.systemImageName)
                .font(AlarmRowStyle.metaIconFont)
                .foregroundStyle(enabled ? Color.primary : Color.secondary.opacity(0.65))
            Text(alarm.missionType.title)
                .lineLimit(1)
        }
        .font(AlarmRowStyle.metaFont)
        .foregroundStyle(Color.secondary.opacity(enabled ? 1 : 0.55))
    }
}
