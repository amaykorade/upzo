//
//  ContentView.swift
//  timer
//
//  Created by Amay Ramaling Korade on 12/05/26.
//

import SwiftUI
#if os(iOS)
import AlarmKit
import UIKit
#endif

struct ContentView: View {
    @StateObject private var alarmStore = AlarmStore()
    @StateObject private var wakeHistory = WakeHistoryStore()
    @AppStorage("settings.prefersDarkMode") private var prefersDarkMode = false
#if os(iOS)
    @Environment(\.scenePhase) private var scenePhaseForAccess
#endif

#if os(iOS)
    @StateObject private var pendingMissionRouter = PendingMissionRouter.shared
    @StateObject private var missionRecoveryStore = MissionRecoveryStore.shared
    @ObservedObject private var onboardingStore = OnboardingStore.shared
    @ObservedObject private var accountStore = AccountStore.shared
    @ObservedObject private var subscriptionStore = SubscriptionStore.shared

    private var shouldShowDedicatedSignIn: Bool {
        !accountStore.isSignedIn
    }

    private var signInFlowMode: SignInFlowMode {
        onboardingStore.skippedOnboardingForReturningUser ? .returningUser : .newUser
    }
    @State private var missionAlarm: Alarm?
    @State private var selectedTab = 0
    @State private var alarmKitState = AlarmManager.shared.authorizationState
    @State private var canScheduleAlarms = false
#endif

    var body: some View {
        Group {
#if os(iOS)
            if !onboardingStore.hasCompletedOnboarding {
                OnboardingFlowView(
                    onFinished: {
                        onboardingStore.markCompleted()
                    },
                    onSignInWithExistingAccount: skipOnboardingForReturningUser
                )
            } else if !CommitmentStore.hasCompletedCommitment {
                CommitmentFlowView {
                    Task { await refreshSchedulingAccess() }
                }
            } else if shouldShowDedicatedSignIn {
                SignInFlowView(mode: signInFlowMode) {
                    Task { await refreshSchedulingAccess() }
                }
                .environmentObject(AccountStore.shared)
            } else if !subscriptionStore.hasActiveSubscription {
                SubscriptionPaywallView {
                    Task {
                        await subscriptionStore.refresh()
                        await refreshSchedulingAccess()
                    }
                }
            } else if !canScheduleAlarms {
                SystemAlarmRequiredView(alarmKitState: $alarmKitState) {
                    Task { await refreshSchedulingAccess() }
                }
            } else {
                mainAppTabView
            }
#else
            macOSTabView
#endif
        }
#if os(iOS)
        .adaptivePhoneLayoutOnPad()
        .task {
            await refreshSchedulingAccess()
            for await state in AlarmManager.shared.authorizationUpdates {
                await MainActor.run {
                    alarmKitState = state
                    if state == .authorized {
                        TabBarAppearance.applySelectedColor(isDarkMode: prefersDarkMode)
                        Task { await alarmStore.rescheduleNotifications() }
                    }
                    Task { await refreshSchedulingAccess() }
                }
            }
        }
        .onChange(of: scenePhaseForAccess) { _, _ in
            Task { await refreshSchedulingAccess() }
            if scenePhaseForAccess == .active {
                restoreMissionAfterTerminationIfNeeded()
                Task {
                    await WakeDeliveryService.shared.appBecameActive(
                        wakeHistory: wakeHistory,
                        alarmStore: alarmStore
                    )
                }
            } else if scenePhaseForAccess == .background {
                Task { await WakeDeliveryService.shared.appEnteredBackground(alarmStore: alarmStore) }
            }
        }
        .onChange(of: subscriptionStore.hasActiveSubscription) { _, isPremium in
            if !isPremium {
                alarmStore.disableAllForExpiredSubscription()
            }
        }
        .onChange(of: accountStore.isSignedIn) { _, signedIn in
            guard signedIn else { return }
            applyReturningUserLaunchShortcutsIfNeeded()
        }
        .onAppear {
            applyReturningUserLaunchShortcutsIfNeeded()
            restoreMissionAfterTerminationIfNeeded()
            Task {
                await refreshSchedulingAccess()
                await WakeDeliveryService.shared.appBecameActive(
                    wakeHistory: wakeHistory,
                    alarmStore: alarmStore
                )
            }
        }
#endif
        .environmentObject(alarmStore)
        .environmentObject(wakeHistory)
        .environmentObject(AlarmAppSettingsStore.shared)
        .environmentObject(NotificationPreferencesStore.shared)
        .environmentObject(AccountStore.shared)
        .environmentObject(SubscriptionStore.shared)
        .preferredColorScheme(prefersDarkMode ? .dark : .light)
    }

#if os(iOS)
    private var mainAppTabView: some View {
        TabView(selection: $selectedTab) {
                HomeView(onOpenAlarms: { selectedTab = 1 })
                .tag(0)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

                AlarmListView()
                    .tag(1)
                    .tabItem {
                        Label("Alarms", systemImage: "alarm")
                    }

                StatsView()
                    .tag(2)
                    .tabItem {
                        Label("Insights", systemImage: "chart.bar")
                    }

                SettingsView()
                    .tag(3)
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .onAppear { TabBarAppearance.applySelectedColor(isDarkMode: prefersDarkMode) }
            .onChange(of: prefersDarkMode) { _, isDark in
                TabBarAppearance.applySelectedColor(isDarkMode: isDark)
            }
            .onOpenURL { url in
                guard url.scheme == "timer" else { return }
                if url.host == "alarms" {
                    selectedTab = 1
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .timerOpenMissionAlarm)) { output in
                guard let idString = output.userInfo?["alarmId"] as? String,
                      let id = UUID(uuidString: idString),
                      let alarm = alarmStore.alarm(id: id)
                else { return }
                missionAlarm = alarm
                PendingMissionRouter.shared.consume()
            }
            .onAppear {
                presentPendingMissionIfAny()
                restoreMissionAfterTerminationIfNeeded()
                OnboardingStore.shared.createStarterAlarmIfNeeded(
                    alarmStore: alarmStore,
                    appSettings: AlarmAppSettingsStore.shared
                )
            }
            .onChange(of: pendingMissionRouter.pendingAlarmID) { _, _ in
                presentPendingMissionIfAny()
            }
            .onChange(of: missionAlarm) { _, newValue in
                let settings = AlarmAppSettingsStore.shared
                if let alarm = newValue {
                    WakeDeliveryService.shared.missionPresentationBegan(for: alarm)
                    // Full-screen mission is enough; skip Dynamic Island to avoid a lingering time pill after dismiss.
                    missionRecoveryStore.markMissionActive(alarmId: alarm.id)
                    AlarmAlertSessionStore.shared.beginNewAlertCycle(alarmId: alarm.id)
                    MissionSnoozeController.shared.clearSnoozeUsage(for: alarm.id)
                    MissionTimingStore.shared.markMissionBegan(for: alarm.id)
                    MissionDuringAlarmAudio.shared.start(
                        alarm: alarm,
                        enabled: settings.alarmDuringMissionEnabled,
                        mixWithRecording: alarm.missionType == .voice
                    )
                } else {
                    missionRecoveryStore.clear()
                    MissionDuringAlarmAudio.shared.stop()
                    WakeLiveActivityController.endIfNeeded()
                }
            }
            .fullScreenCover(item: $missionAlarm) { alarm in
                MissionExecutionView(
                    alarm: alarm,
                    allowsDismissWithoutMission: false,
                    onMissionCompleted: {
                        MissionSnoozeController.shared.clearSnoozeUsage(for: alarm.id)
                        wakeHistory.recordCompletion(
                            alarmId: alarm.id,
                            missionType: alarm.missionType,
                            alarmSound: alarm.alarmSound
                        )
                        AppReviewCoordinator.considerPromptAfterSuccessfulWake(
                            totalSuccessfulWakes: wakeHistory.totalSuccessfulWakes,
                            streakDays: wakeHistory.currentStreakDays
                        )
                        AlarmAlertSessionStore.shared.markMissionCompleted(alarmId: alarm.id)
                        Task {
                            await WakeDeliveryService.shared.missionCompleted(alarmId: alarm.id)
                            missionRecoveryStore.clear()
                            missionAlarm = nil
                        }
                    },
                    onDismiss: {
                        MissionTimingStore.shared.clear(for: alarm.id)
                        missionRecoveryStore.clear()
                        WakeLiveActivityController.endIfNeeded()
                        Task {
                            await WakeDeliveryService.shared.missionUIClosedWithoutCompletion(alarmId: alarm.id)
                        }
                        missionAlarm = nil
                    }
                )
                .interactiveDismissDisabled(true)
            }
            .alarmKitMissionBridge(missionAlarm: $missionAlarm)
    }

    private func presentPendingMissionIfAny() {
        guard missionAlarm == nil,
              let id = pendingMissionRouter.pendingAlarmID,
              let alarm = alarmStore.alarm(id: id)
        else { return }
        missionAlarm = alarm
        pendingMissionRouter.consume()
    }

    private func skipOnboardingForReturningUser() {
        onboardingStore.markSkippedForReturningUser()
        CommitmentStore.markCompleted()
    }

    private func restoreMissionAfterTerminationIfNeeded() {
        guard missionAlarm == nil else { return }
        missionRecoveryStore.refreshFromDisk()
        guard let id = missionRecoveryStore.pendingMissionAlarmID else { return }
        guard let alarm = alarmStore.alarm(id: id), alarm.isEnabled else {
            missionRecoveryStore.clear()
            return
        }
        missionAlarm = alarm
    }

    /// After reinstall or Sign in with Apple restore — skip quiz and commitment.
    private func applyReturningUserLaunchShortcutsIfNeeded() {
        guard accountStore.isSignedIn else { return }
        if !onboardingStore.hasCompletedOnboarding {
            onboardingStore.markSkippedForReturningUser()
        }
        if !CommitmentStore.hasCompletedCommitment {
            CommitmentStore.markCompleted()
        }
    }

    @MainActor
    private func refreshSchedulingAccess() async {
        alarmKitState = await AppPermissions.syncAlarmKitAuthorizationState()
        canScheduleAlarms = await AppSchedulingAccess.canDeliverAlarms()
        if canScheduleAlarms {
            TabBarAppearance.applySelectedColor(isDarkMode: prefersDarkMode)
            OnboardingStore.shared.createStarterAlarmIfNeeded(
                alarmStore: alarmStore,
                appSettings: AlarmAppSettingsStore.shared
            )
            await alarmStore.rescheduleNotifications()
        }
    }
#else
    private var macOSTabView: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            AlarmListView()
                .tabItem {
                    Label("Alarms", systemImage: "alarm")
                }

            StatsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
#endif
}

#if os(iOS)
/// Tab bar selected icon/label only — does not change sun accent elsewhere in the app.
enum TabBarAppearance {
    static func applySelectedColor(isDarkMode: Bool) {
        let selected: UIColor = isDarkMode ? .white : .black
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        [appearance.stackedLayoutAppearance, appearance.inlineLayoutAppearance, appearance.compactInlineLayoutAppearance]
            .forEach { item in
                item.selected.iconColor = selected
                item.selected.titleTextAttributes = [.foregroundColor: selected]
            }

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().tintColor = selected
    }
}
#endif

#Preview {
    ContentView()
}
