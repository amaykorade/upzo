#if os(iOS)
import SwiftUI
import UIKit

/// Story-driven onboarding: psychology questions → insights → plan setup.
struct OnboardingFlowView: View {
    @EnvironmentObject private var alarmStore: AlarmStore
    @EnvironmentObject private var appSettings: AlarmAppSettingsStore
    @ObservedObject private var onboardingStore = OnboardingStore.shared

    var onFinished: () -> Void
    /// Jumps to Sign in with Apple (skips questions, commitment, and plan setup).
    var onSignInWithExistingAccount: (() -> Void)?

    @State private var step = Step.welcome
    @FocusState private var nameFieldFocused: Bool

    @State private var userName = ""
    @State private var gender: OnboardingGender?
    @State private var morningPerson: OnboardingMorningPerson?
    @State private var referralSource: OnboardingReferralSource?
    @State private var morningStruggle: OnboardingMorningStruggle?
    @State private var alarmCount: OnboardingAlarmCount?
    @State private var trustFirstAlarm: OnboardingTrustFirstAlarm?
    @State private var backToSleep: OnboardingBackToSleep?
    @State private var nightFeeling: OnboardingNightFeeling?
    @State private var alarmThought: OnboardingAlarmThought?
    @State private var bedNegotiation: OnboardingBedNegotiation?
    @State private var wakeDate = Alarm.pickerDate(hour: 7, minute: 0)
    @State private var morningFeeling: OnboardingMorningFeeling?
    @State private var awakeDelay: OnboardingAwakeDelay?
    @State private var brainFogRemedy: OnboardingBrainFogRemedy?
    @State private var repeatDays: Set<Weekday> = OnboardingProfile.defaultWeekdayPreset
    @State private var missionChoice: OnboardingMissionChoice?
    @State private var strictness: OnboardingStrictness?
    @State private var phoneHabit: OnboardingPhoneHabit?

    private enum Step {
        static let welcome = 0
        static let gender = 1
        static let morningPerson = 2
        static let referral = 3
        static let obstacle = 4
        static let appHelp = 5
        static let alarmCount = 6
        static let trustWake = 7
        static let backToSleep = 8
        static let nightFeeling = 9
        static let alarmThought = 10
        static let negotiate = 11
        static let biology = 12
        static let wakeTime = 13
        static let realisticTarget = 14
        static let morningFeeling = 15
        static let awakeDelay = 16
        static let brainFog = 17
        static let motivation1 = 18
        static let motivation2 = 19
        static let name = 20
        static let repeatDays = 21
        static let mission = 22
        static let strictness = 23
        static let phone = 24
        static let plan = 25
    }

  private static let questionStepOrder: [Int] = [
        Step.gender, Step.morningPerson, Step.referral, Step.obstacle,
        Step.alarmCount, Step.trustWake, Step.backToSleep, Step.nightFeeling,
        Step.alarmThought, Step.negotiate, Step.morningFeeling, Step.awakeDelay,
        Step.brainFog, Step.mission, Step.strictness, Step.phone,
    ]

    var body: some View {
        VStack(spacing: 0) {
            topBar

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepContent
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .timerScreenBackground()
    }

    // MARK: - Chrome

    private var topBar: some View {
        HStack {
            if step > Step.welcome {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                }
                .accessibilityLabel("Back")
            } else {
                Color.clear.frame(width: 28, height: 28)
            }

            Spacer()

            if let q = questionNumber(for: step) {
                Text("Question \(q) of \(Self.questionStepOrder.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, AppTheme.screenHorizontalPadding)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if step == Step.welcome, let onSignInWithExistingAccount {
                Button(action: onSignInWithExistingAccount) {
                    Text("Already have an account? Sign in")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 10)

                Divider()
            }

            Button(action: primaryAction) {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(!canContinue)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func questionNumber(for step: Int) -> Int? {
        guard let index = Self.questionStepOrder.firstIndex(of: step) else { return nil }
        return index + 1
    }

    private var canContinue: Bool {
        switch step {
        case Step.welcome: true
        case Step.gender: gender != nil
        case Step.morningPerson: morningPerson != nil
        case Step.referral: referralSource != nil
        case Step.obstacle: morningStruggle != nil
        case Step.appHelp, Step.biology, Step.realisticTarget, Step.motivation1, Step.motivation2: true
        case Step.alarmCount: alarmCount != nil
        case Step.trustWake: trustFirstAlarm != nil
        case Step.backToSleep: backToSleep != nil
        case Step.nightFeeling: nightFeeling != nil
        case Step.alarmThought: alarmThought != nil
        case Step.negotiate: bedNegotiation != nil
        case Step.wakeTime: true
        case Step.morningFeeling: morningFeeling != nil
        case Step.awakeDelay: awakeDelay != nil
        case Step.brainFog: brainFogRemedy != nil
        case Step.name: isNameValid
        case Step.repeatDays: !repeatDays.isEmpty
        case Step.mission: missionChoice != nil
        case Step.strictness: strictness != nil
        case Step.phone: phoneHabit != nil
        case Step.plan: true
        default: false
        }
    }

    private var primaryButtonTitle: String {
        switch step {
        case Step.welcome: "Get started"
        case Step.plan: "Continue"
        default: "Continue"
        }
    }

    private func primaryAction() {
        if step < Step.plan {
            let next = step + 1
            applySmartDefaults(whenEntering: next)
            withAnimation(.easeInOut(duration: 0.2)) { step = next }
            return
        }
        finishOnboarding()
    }

    private var trimmedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isNameValid: Bool {
        let name = trimmedUserName
        return name.count >= 2 && name.count <= 32
    }

    private var wakeTimeLabel: String {
        let time = Alarm.pickerTime(from: wakeDate)
        return Alarm.formattedTime(hour: time.hour, minute: time.minute)
    }

    private func applySmartDefaults(whenEntering nextStep: Int) {
        if nextStep == Step.mission, missionChoice == nil {
            if backToSleep == .often || bedNegotiation == .almostAlways {
                missionChoice = .shake
            } else if morningFeeling == .groggy || brainFogRemedy == .nothing {
                missionChoice = .math
            } else if morningPerson == .yes {
                missionChoice = .steps
            } else if alarmThought == .snooze || alarmThought == .fiveMore {
                missionChoice = .shake
            }
        }
        if nextStep == Step.strictness, strictness == nil {
            if bedNegotiation == .almostAlways || backToSleep == .often {
                strictness = .strict
            } else if trustFirstAlarm == .yes && backToSleep == .never {
                strictness = .gentle
            } else {
                strictness = .standard
            }
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case Step.welcome: welcomeStep
        case Step.gender: questionShell(
            title: "What is your gender?",
            subtitle: "Optional for personalization — we don't share this."
        ) { optionList(OnboardingGender.allCases, selection: $gender) }
        case Step.morningPerson: questionShell(
            title: "Do you consider yourself a morning person?",
            subtitle: "Be honest — there's no wrong answer."
        ) { optionList(OnboardingMorningPerson.allCases, selection: $morningPerson) }
        case Step.referral: questionShell(
            title: "Where did you hear about us?",
            subtitle: "Helps us improve how we reach people like you."
        ) { optionList(OnboardingReferralSource.allCases, selection: $referralSource) }
        case Step.obstacle: questionShell(
            title: "What's your biggest obstacle to getting out of bed?",
            subtitle: "We'll focus your plan on this."
        ) { optionList(OnboardingMorningStruggle.allCases, selection: $morningStruggle) }
        case Step.appHelp: OnboardingChatHelpPage()
        case Step.alarmCount: questionShell(
            title: "How many alarms do you usually set?",
            subtitle: "Many people stack alarms when one isn't enough."
        ) { optionList(OnboardingAlarmCount.allCases, selection: $alarmCount) }
        case Step.trustWake: questionShell(
            title: "Do you trust yourself to wake up after the first alarm?",
            subtitle: "No judgment — most people don't, at least not every day."
        ) { optionList(OnboardingTrustFirstAlarm.allCases, selection: $trustFirstAlarm) }
        case Step.backToSleep: questionShell(
            title: "Do you ever turn off your alarm and go back to sleep?",
            subtitle: "This is one of the most common wake-up problems."
        ) { optionList(OnboardingBackToSleep.allCases, selection: $backToSleep) }
        case Step.nightFeeling: questionShell(
            title: "How do you usually feel when you set your alarm at night?",
            subtitle: "Your evening mindset affects your morning."
        ) { optionList(OnboardingNightFeeling.allCases, selection: $nightFeeling) }
        case Step.alarmThought: questionShell(
            title: "When the alarm rings, what's your immediate thought?",
            subtitle: "The first few seconds decide whether you get up."
        ) { optionList(OnboardingAlarmThought.allCases, selection: $alarmThought) }
        case Step.negotiate: questionShell(
            title: "Do you negotiate with yourself to stay in bed?",
            subtitle: "That inner debate is sleep inertia talking."
        ) { optionList(OnboardingBedNegotiation.allCases, selection: $bedNegotiation) }
        case Step.biology: OnboardingInsightPage(
            title: "It's not a discipline problem",
            bodyText: "You aren't lazy — you're fighting biology. When the alarm rings, your prefrontal cortex (the self-control part) is still coming online. That sleep inertia makes snoozing feel like the only option.",
            systemImage: "brain.head.profile"
        )
        case Step.wakeTime: questionShell(
            title: "What time do you usually need to get out of bed?",
            subtitle: "Weekday target — you can add more alarms later."
        ) { wakeTimePicker }
        case Step.realisticTarget: OnboardingRealisticWakePage(wakeTimeLabel: wakeTimeLabel)
        case Step.morningFeeling: questionShell(
            title: "How do you feel immediately after waking up?",
            subtitle: "We'll tune how intense your mission should be."
        ) { optionList(OnboardingMorningFeeling.allCases, selection: $morningFeeling) }
        case Step.awakeDelay: questionShell(
            title: "How long does it usually take you to feel fully awake?",
            subtitle: "Brain fog is normal — missions help shorten it."
        ) { optionList(OnboardingAwakeDelay.allCases, selection: $awakeDelay) }
        case Step.brainFog: questionShell(
            title: "What do you currently rely on to clear that brain fog?",
            subtitle: "We'll build on what already works for you."
        ) { optionList(OnboardingBrainFogRemedy.allCases, selection: $brainFogRemedy) }
        case Step.motivation1: OnboardingMotivationPage(
            title: "You're closer than you think",
            subtitle: "Small physical actions — standing, walking, speaking — signal your body that sleep is over.",
            systemImage: "figure.walk"
        )
        case Step.motivation2: OnboardingMotivationPage(
            title: "One alarm. One mission. Actually up.",
            subtitle: "\(AppBrand.name) won't let you off until your mission is done — no more silent snooze spiral.",
            systemImage: "sun.max.fill"
        )
        case Step.name: questionShell(
            title: "What's your first name?",
            subtitle: "We'll personalize your plan — just what you go by."
        ) { nameInput }
        case Step.repeatDays: questionShell(
            title: "Which days should your alarm repeat?",
            subtitle: "Pick at least one day."
        ) { onboardingWeekdayPicker }
        case Step.mission: questionShell(
            title: "What would actually get you out of bed?",
            subtitle: "You'll finish this mission to turn the alarm off."
        ) { optionList(OnboardingMissionChoice.allCases, selection: $missionChoice) }
        case Step.strictness: questionShell(
            title: "How strict should we be?",
            subtitle: "Strict mode makes the mission harder to fake."
        ) { optionList(OnboardingStrictness.allCases, selection: $strictness) }
        case Step.phone: questionShell(
            title: "Where is your phone at night?",
            subtitle: "Across the room can make missions easier."
        ) { optionList(OnboardingPhoneHabit.allCases, selection: $phoneHabit) }
        case Step.plan: planStep
        default: EmptyView()
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            AppLogoView(size: 72, style: .appIcon)

            Text("Mornings don't have to feel like a fight")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text("Answer a few honest questions. We'll show you why snoozing happens — and build a wake-up plan that works with your brain, not against it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("New here? Tap Get started. Returning user? Sign in below to skip the quiz.")
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .padding(.top, 16)
    }

    private var nameInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Your first name", text: $userName)
                .textContentType(.givenName)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.words)
                .submitLabel(.continue)
                .focused($nameFieldFocused)
                .onSubmit {
                    if isNameValid { primaryAction() }
                }
                .font(.title3.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .timerCardBackground(highlighted: isNameValid)

            if !userName.isEmpty && !isNameValid {
                Text("Please enter at least 2 characters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                nameFieldFocused = true
            }
        }
    }

    private var wakeTimePicker: some View {
        DatePicker(
            "Wake time",
            selection: $wakeDate,
            displayedComponents: .hourAndMinute
        )
        .datePickerStyle(.wheel)
        .labelsHidden()
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .timerCardBackground()
    }

    private var onboardingWeekdayPicker: some View {
        let days = Weekday.sundayThroughSaturday
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(days, id: \.self) { day in
                let selected = repeatDays.contains(day)
                Button {
                    if selected { repeatDays.remove(day) } else { repeatDays.insert(day) }
                } label: {
                    Text(day.compactStripLabel)
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selected ? AppTheme.sunAccent.opacity(0.2) : AppTheme.cardFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(selected ? AppTheme.sunAccent : AppTheme.cardStroke, lineWidth: selected ? 1.5 : 1)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
        }
    }

    private var planStep: some View {
        let profile = buildProfile()

        return VStack(alignment: .leading, spacing: 20) {
            AppLogoView(size: 48, style: .mark)

            if let greeting = profile.planGreeting {
                Text(greeting)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.sunAccent)
            }

            Text("Your wake-up plan")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 12) {
                Text(profile.planHeadline)
                    .font(.title3.weight(.semibold))

                if let callback = profile.struggleCallback {
                    Text(callback)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                planRow(icon: "alarm.fill", title: "Wake time", value: Alarm.formattedTime(hour: profile.wakeHour, minute: profile.wakeMinute))
                planRow(icon: profile.recommendedMission.systemImageName, title: "Mission", value: profile.recommendedMission.title)
                planRow(icon: "calendar", title: "Repeat", value: AlarmRowFormatting.repeatSummary(days: profile.repeatDays))
                planRow(icon: "shield.checkered", title: "Mode", value: profile.strictness?.title ?? "Standard")
            }
            .padding(16)
            .timerCardBackground(highlighted: true)

            Text(profile.planDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private func planRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.sunAccent)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.trailing)
        }
    }

    // MARK: - Reusable question UI

    private func questionShell<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }

    private func optionList<Option: Identifiable & Hashable & Equatable>(
        _ options: [Option],
        selection: Binding<Option?>
    ) -> some View where Option: OnboardingOptionDisplayable {
        VStack(spacing: 10) {
            ForEach(options) { option in
                optionCard(option: option, isSelected: selection.wrappedValue == option) {
                    selection.wrappedValue = option
                }
            }
        }
    }

    private func onboardingOptionIcon(_ systemName: String, isSelected: Bool) -> some View {
        let resolved = UIImage(systemName: systemName) != nil ? systemName : "circle.fill"
        return Image(systemName: resolved)
            .font(.title2)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isSelected ? AppTheme.sunAccent : Color.primary.opacity(0.45))
            .frame(width: 28, height: 28)
    }

    private func optionCard<Option: OnboardingOptionDisplayable>(
        option: Option,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                onboardingOptionIcon(option.optionSystemImage, isSelected: isSelected)

                Text(option.optionTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(AppTheme.sunAccent)
                }
            }
            .padding(16)
            .timerCardBackground(highlighted: isSelected)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Finish

    private func buildProfile() -> OnboardingProfile {
        let time = Alarm.pickerTime(from: wakeDate)
        return OnboardingProfile(
            firstName: trimmedUserName.isEmpty ? nil : trimmedUserName,
            gender: gender,
            morningPerson: morningPerson,
            referralSource: referralSource,
            alarmCount: alarmCount,
            trustFirstAlarm: trustFirstAlarm,
            backToSleep: backToSleep,
            nightFeeling: nightFeeling,
            alarmThought: alarmThought,
            bedNegotiation: bedNegotiation,
            morningFeeling: morningFeeling,
            awakeDelay: awakeDelay,
            brainFogRemedy: brainFogRemedy,
            ageRange: nil,
            morningStruggle: morningStruggle,
            snoozeFrequency: derivedSnoozeFrequency,
            sleeperType: derivedSleeperType,
            wakeGoal: derivedWakeGoal,
            wakeHour: time.hour,
            wakeMinute: time.minute,
            repeatDays: repeatDays.sorted(),
            missionChoice: missionChoice,
            strictness: strictness,
            phoneHabit: phoneHabit,
            completedAt: nil
        )
    }

    private var derivedSnoozeFrequency: OnboardingSnoozeFrequency? {
        switch backToSleep {
        case .often: return .threePlus
        case .sometimes: return .onceOrTwice
        case .never: return .rarely
        case nil: return nil
        }
    }

    private var derivedSleeperType: OnboardingSleeperType? {
        switch morningPerson {
        case .yes: return .light
        case .sometimes: return .average
        case .no: return .heavy
        case nil: return nil
        }
    }

    private var derivedWakeGoal: OnboardingWakeGoal? {
        switch morningStruggle {
        case .groggy: return .lessStress
        case .inconsistent: return .routine
        case .oversleep, .snooze, .alarmFails: return .onTime
        case nil: return .onTime
        }
    }

    private func finishOnboarding() {
        let profile = buildProfile()
        onboardingStore.applyProfile(profile, appSettings: appSettings, alarmStore: alarmStore)
        onboardingStore.markCompleted()
        onFinished()
    }
}

// MARK: - Option display protocol

private protocol OnboardingOptionDisplayable {
    var optionTitle: String { get }
    var optionSystemImage: String { get }
}

extension OnboardingGender: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingMorningPerson: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingReferralSource: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingAlarmCount: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingTrustFirstAlarm: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingBackToSleep: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingNightFeeling: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingAlarmThought: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingBedNegotiation: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingMorningFeeling: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingAwakeDelay: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingBrainFogRemedy: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingMorningStruggle: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingMissionChoice: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingStrictness: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

extension OnboardingPhoneHabit: OnboardingOptionDisplayable {
    var optionTitle: String { title }
    var optionSystemImage: String { systemImage }
}

#Preview {
    OnboardingFlowView(onFinished: {})
        .environmentObject(AlarmStore())
        .environmentObject(AlarmAppSettingsStore.shared)
}
#endif
