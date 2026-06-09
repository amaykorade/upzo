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
    @ObservedObject private var wakeSession = WakeSessionStore.shared
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
        platformRoot
            .environmentObject(alarmStore)
            .environmentObject(wakeHistory)
            .environmentObject(AlarmAppSettingsStore.shared)
            .environmentObject(NotificationPreferencesStore.shared)
            .environmentObject(AccountStore.shared)
            .environmentObject(SubscriptionStore.shared)
            .preferredColorScheme(prefersDarkMode ? .dark : .light)
    }

#if os(iOS)
    private var platformRoot: some View {
        iosMissionShell
            .adaptivePhoneLayoutOnPad()
            .task { await runAlarmAuthorizationListener() }
            .onChange(of: scenePhaseForAccess) { _, _ in handleScenePhaseChange() }
            .onChange(of: subscriptionStore.hasActiveSubscription) { _, isPremium in
                if !isPremium { alarmStore.disableAllForExpiredSubscription() }
            }
            .onChange(of: accountStore.isSignedIn) { _, signedIn in
                guard signedIn else { return }
                applyReturningUserLaunchShortcutsIfNeeded()
            }
            .onAppear { handleRootAppear() }
            .task { await retryPresentMissionIfOwed() }
            .onReceive(NotificationCenter.default.publisher(for: .timerOpenMissionAlarm)) { output in
                handleOpenMissionNotification(output)
            }
            .onChange(of: pendingMissionRouter.pendingAlarmID) { _, _ in presentMissionIfOwed() }
            .onChange(of: wakeSession.session) { _, _ in presentMissionIfOwed() }
            .onChange(of: missionAlarm) { _, newValue in handleMissionAlarmChange(newValue) }
            .alarmKitMissionBridge(missionAlarm: $missionAlarm)
    }

    private var iosMissionShell: some View {
        ZStack {
            rootContent
            missionOverlay
        }
    }

    private func handleRootAppear() {
        applyReturningUserLaunchShortcutsIfNeeded()
        presentMissionIfOwed()
        Task { await retryPresentMissionIfOwed() }
    }

    private func handleScenePhaseChange() {
        Task { await refreshSchedulingAccess() }
        guard scenePhaseForAccess == .active else {
            if scenePhaseForAccess == .background {
                Task { await WakeDeliveryService.shared.appEnteredBackground(alarmStore: alarmStore) }
            }
            return
        }
        presentMissionIfOwed()
        Task { await retryPresentMissionIfOwed() }
    }

    private func handleOpenMissionNotification(_ output: Notification) {
        guard let idString = output.userInfo?["alarmId"] as? String,
              let id = UUID(uuidString: idString)
        else { return }
        presentMissionIfOwed(preferredAlarmId: id)
    }

    private func handleMissionAlarmChange(_ newValue: Alarm?) {
        let settings = AlarmAppSettingsStore.shared
        if let alarm = newValue {
            WakeDeliveryService.shared.missionPresentationBegan(for: alarm)
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

    private func runAlarmAuthorizationListener() async {
        await refreshSchedulingAccess()
        for await state in AlarmManager.shared.authorizationUpdates {
            alarmKitState = state
            if state == .authorized {
                TabBarAppearance.applySelectedColor(isDarkMode: prefersDarkMode)
                Task { await alarmStore.rescheduleNotifications() }
            }
            await refreshSchedulingAccess()
        }
    }
#else
    private var platformRoot: some View {
        macOSTabView
    }
#endif

#if os(iOS)
    @ViewBuilder
    private var rootContent: some View {
        Group {
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
        }
    }

    @ViewBuilder
    private var missionOverlay: some View {
        if let alarm = missionAlarm {
            MissionExecutionView(
                alarm: alarm,
                allowsDismissWithoutMission: false,
                onMissionCompleted: {
                    let completedAlarmId = alarm.id
                    MissionSnoozeController.shared.clearSnoozeUsage(for: completedAlarmId)
                    wakeHistory.recordCompletion(
                        alarmId: completedAlarmId,
                        missionType: alarm.missionType,
                        alarmSound: alarm.alarmSound
                    )
                    AppReviewCoordinator.considerPromptAfterSuccessfulWake(
                        totalSuccessfulWakes: wakeHistory.totalSuccessfulWakes,
                        streakDays: wakeHistory.currentStreakDays
                    )
                    AlarmAlertSessionStore.shared.markMissionCompleted(alarmId: completedAlarmId)
                    missionRecoveryStore.clear()
                    missionAlarm = nil
                    Task {
                        await WakeDeliveryService.shared.missionCompleted(alarmId: completedAlarmId)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
            .zIndex(1)
            .transition(.opacity)
        }
    }

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
            .onAppear {
                OnboardingStore.shared.createStarterAlarmIfNeeded(
                    alarmStore: alarmStore,
                    appSettings: AlarmAppSettingsStore.shared
                )
            }
    }

    /// Presents the owed wake mission above onboarding, paywall, or setup gates.
    private func presentMissionIfOwed(preferredAlarmId: UUID? = nil) {
        guard missionAlarm == nil else { return }

        missionRecoveryStore.refreshFromDisk()
        wakeSession.restoreIfNeeded()

        var seen = Set<UUID>()
        let candidateIDs: [UUID] = [
            preferredAlarmId,
            pendingMissionRouter.pendingAlarmID,
            wakeSession.pendingMissionAlarmId,
            missionRecoveryStore.pendingMissionAlarmID,
        ].compactMap { id in
            guard let id, seen.insert(id).inserted else { return nil }
            return id
        }

        for id in candidateIDs {
            guard let alarm = resolveAlarmForMission(id: id) else { continue }
            missionAlarm = alarm
            pendingMissionRouter.consume()
            return
        }
    }

    private func resolveAlarmForMission(id: UUID) -> Alarm? {
        if let alarm = alarmStore.alarm(id: id) {
            return alarm
        }
        return AlarmStore.alarmFromDisk(id: id)
    }

    @MainActor
    private func retryPresentMissionIfOwed() async {
        let owedId = await WakeDeliveryService.shared.reconcileAlarmKitOnBecomeActive(
            wakeHistory: wakeHistory,
            alarmStore: alarmStore
        )
        presentMissionIfOwed(preferredAlarmId: owedId)

        for _ in 0 ..< 12 {
            if missionAlarm != nil { break }
            presentMissionIfOwed()
            if missionAlarm != nil { break }
            try? await Task.sleep(for: .milliseconds(250))
        }

        await WakeDeliveryService.shared.appBecameActive(
            wakeHistory: wakeHistory,
            alarmStore: alarmStore
        )
        presentMissionIfOwed(preferredAlarmId: owedId)
        await refreshSchedulingAccess()
    }

    private func skipOnboardingForReturningUser() {
        onboardingStore.markSkippedForReturningUser()
        CommitmentStore.markCompleted()
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
            wakeSession.restoreIfNeeded()
            if wakeSession.pendingMissionAlarmId == nil, missionAlarm == nil {
                await alarmStore.rescheduleNotifications()
            }
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
