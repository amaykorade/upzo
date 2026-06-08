#if os(iOS)
import UIKit
#endif
import SwiftUI

struct StatsView: View {
    @EnvironmentObject private var wakeHistory: WakeHistoryStore
    @EnvironmentObject private var appSettings: AlarmAppSettingsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.screenBlockSpacing) {
                    TimerScreenTitle(title: "Insights")

                    streakOverviewCard

                    insightsMetricsCard

                    badgesSection
                }
                .timerTabScreenInsets()
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
            .scrollContentBackground(.hidden)
            .timerScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func insightsSectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTheme.sectionHeaderFont)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
            .padding(.bottom, 2)
    }

    private var avgWakeTimeMetricValue: String {
        let average = wakeHistory.averageWakeTimeDisplay ?? "—"
        guard appSettings.hasGoalWakeTime else { return average }
        return "\(average) · goal \(appSettings.goalWakeTimeDisplay)"
    }

    private var insightsMetricsCard: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ],
            spacing: 10
        ) {
            insightMetricCell(
                title: "Avg wake time",
                value: avgWakeTimeMetricValue,
                icon: "sunrise.fill"
            )
            insightMetricCell(
                title: "Avg response",
                value: wakeHistory.averageResponseDisplay ?? "—",
                icon: "bolt.fill"
            )
            insightMetricCell(
                title: "Favorite mission",
                value: wakeHistory.favoriteMissionDisplay ?? "—",
                icon: wakeHistory.favoriteMission?.systemImageName ?? "questionmark.circle"
            )
            insightMetricCell(
                title: "Favorite sound",
                value: wakeHistory.favoriteSoundDisplay ?? "—",
                icon: wakeHistory.favoriteSound?.systemImageName ?? "waveform"
            )
        }
    }

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            insightsSectionHeader("Badges earned")

            if wakeHistory.earnedBadges.isEmpty {
                Text("Complete missions to unlock badges.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .timerCardBackground()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(wakeHistory.earnedBadges) { badge in
                            badgeCell(badge)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func insightMetricCell(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .timerCardBackground()
    }

    private func badgeCell(_ badge: WakeBadge) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: badge.systemImageName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(badge.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: 84)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .timerCardBackground()
        .accessibilityLabel("Badge earned: \(badge.title)")
    }

    private var streakOverviewCard: some View {
        let streakDays = wakeHistory.currentStreakDays
        let streakLabel = "day streak"

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 52, height: 52, alignment: .center)
                    .accessibilityHidden(true)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(streakDays)")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    Text(streakLabel)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(streakDays) \(streakLabel)")

            WeekActivityStripView(days: WeekActivityStripView.lastSevenDays)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .timerCardBackground()
    }

}

#Preview {
    StatsView()
        .environmentObject(WakeHistoryStore.mock())
        .environmentObject(AlarmAppSettingsStore.shared)
}
