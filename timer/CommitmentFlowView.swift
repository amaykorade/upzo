#if os(iOS)
import SwiftUI

/// Post-onboarding commitment: social proof comparison → signed promise to wake up.
struct CommitmentFlowView: View {
    @ObservedObject private var onboardingStore = OnboardingStore.shared

    var onFinished: () -> Void

    @State private var step = 0
    @State private var signatureStrokes: [[CGPoint]] = []
    @State private var currentStroke: [CGPoint] = []
    @State private var signedDate = Date()

    private var wakeTimeLabel: String {
        guard let profile = onboardingStore.profile else { return "your alarm time" }
        return Alarm.formattedTime(hour: profile.wakeHour, minute: profile.wakeMinute)
    }

    private var hasSignature: Bool {
        !signatureStrokes.isEmpty || !currentStroke.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            if step > 0 {
                HStack {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { step -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                    Spacer()
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, 12)
            }

            ScrollView {
                Group {
                    if step == 0 {
                        comparisonStep
                    } else {
                        signatureStep
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, AppTheme.screenHorizontalPadding)
                .padding(.top, step == 0 ? 20 : 8)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)

            bottomBar
        }
        .timerScreenBackground()
    }

    // MARK: - Step 1: Comparison

    private var comparisonStep: some View {
        VStack(spacing: 28) {
            AppLogoView(size: 44, style: .mark)
                .frame(maxWidth: .infinity, alignment: .leading)

            comparisonHeader
            WakeUpComparisonChart()
            comparisonFooter
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonHeader: some View {
        VStack(spacing: 10) {
            Text("Get out of bed")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("5×")
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.sunAccent)
                Text("faster")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }

            Text("with \(AppBrand.name) vs on your own")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
    }

    private var comparisonFooter: some View {
        Text("Wake-up missions engage your body and brain when willpower is still waking up — so you're less likely to negotiate yourself back to sleep.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 4)
    }

    // MARK: - Step 2: Signature

    private var signatureStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Sign your commitment")
                .font(.system(size: 28, weight: .bold, design: .rounded))

            VStack(alignment: .leading, spacing: 12) {
                (Text("Promise yourself that you will wake up tomorrow at ")
                 + Text(wakeTimeLabel).fontWeight(.semibold)
                 + Text(" when your alarm goes off."))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Sign to make it official")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    SignaturePad(
                        strokes: $signatureStrokes,
                        currentStroke: $currentStroke
                    )
                    .frame(height: 140)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppTheme.cardFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(AppTheme.cardStroke, lineWidth: 1)
                    )

                    if hasSignature {
                        Button("Clear") {
                            signatureStrokes = []
                            currentStroke = []
                        }
                        .font(.caption.weight(.semibold))
                        .padding(10)
                    } else {
                        Text("Sign here")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(12)
                            .allowsHitTesting(false)
                    }
                }

                if hasSignature {
                    Text("Signed on \(signedDateLabel)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var signedDateLabel: String {
        signedDate.formatted(.dateTime.month(.wide).day().year())
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: primaryAction) {
                Text(step == 0 ? "Continue" : "I'm committed")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
            .disabled(step == 1 && !hasSignature)
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.vertical, 12)
        }
        .background(.bar)
    }

    private func primaryAction() {
        if step == 0 {
            withAnimation(.easeInOut(duration: 0.2)) { step = 1 }
            return
        }
        signedDate = Date()
        CommitmentStore.markCompleted()
        onFinished()
    }
}

// MARK: - Comparison chart

private struct WakeUpComparisonChart: View {
    private let chartHeight: CGFloat = 168
    private let barAreaHeight: CGFloat = 120

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 12) {
                comparisonColumn(
                    title: "On your own",
                    multiplier: "1×",
                    barFraction: 0.22,
                    accent: Color.secondary.opacity(0.45),
                    icon: "bed.double.fill"
                )

                vsDivider

                comparisonColumn(
                    title: AppBrand.name,
                    multiplier: "5×",
                    barFraction: 1.0,
                    accent: AppTheme.sunAccent,
                    icon: "sunrise.fill",
                    isHighlighted: true
                )
            }
            .frame(height: chartHeight)
            .padding(.horizontal, 8)
            .padding(.top, 20)

            Divider()
                .padding(.top, 16)

            Text("Mission-based wake-ups vs snooze-only alarms")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .fill(AppTheme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous)
                .strokeBorder(AppTheme.sunAccent.opacity(0.2), lineWidth: 1)
        )
    }

    private var vsDivider: some View {
        VStack {
            Spacer(minLength: 0)
            Text("vs")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                )
                .padding(.bottom, barAreaHeight * 0.42)
        }
        .frame(width: 44)
    }

    private func comparisonColumn(
        title: String,
        multiplier: String,
        barFraction: CGFloat,
        accent: Color,
        icon: String,
        isHighlighted: Bool = false
    ) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(accent.opacity(isHighlighted ? 0.18 : 0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
            }
            .padding(.bottom, 10)

            Text(multiplier)
                .font(.system(size: isHighlighted ? 36 : 28, weight: .bold, design: .rounded))
                .foregroundStyle(isHighlighted ? accent : .primary)
                .padding(.bottom, 12)

            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: barAreaHeight)

                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(isHighlighted ? 0.95 : 0.55),
                                accent.opacity(isHighlighted ? 0.65 : 0.35),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(12, barAreaHeight * barFraction))
            }
            .frame(height: barAreaHeight)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isHighlighted ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Signature pad

private struct SignaturePad: View {
    @Binding var strokes: [[CGPoint]]
    @Binding var currentStroke: [CGPoint]

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let allStrokes = strokes + (currentStroke.isEmpty ? [] : [currentStroke])
                for stroke in allStrokes where stroke.count > 1 {
                    var path = Path()
                    path.move(to: stroke[0])
                    for point in stroke.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(.primary),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let point = value.location
                        let clamped = CGPoint(
                            x: min(max(0, point.x), geometry.size.width),
                            y: min(max(0, point.y), geometry.size.height)
                        )
                        currentStroke.append(clamped)
                    }
                    .onEnded { _ in
                        if !currentStroke.isEmpty {
                            strokes.append(currentStroke)
                            currentStroke = []
                        }
                    }
            )
        }
    }
}

#Preview {
    CommitmentFlowView(onFinished: {})
}
#endif
